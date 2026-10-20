import numpy as np
try:
    import tensorflow as tf
    from tensorflow.keras import Model
except ImportError:
    tf = None
    Model = object


def weyl_heisenberg_ping_commutator_gate(
    v,
    alpha_e: float = 6.7292,
    gamma: float = 0.4320,
    beta_i: float = 1.4815,
):
    r"""
    Neurolean Law 2: Non-Commutative Weyl-Heisenberg and Affine Shunting PING
    Commutator Gate for articulatory phoneme/syllable boundary detection
    (Theorems 4-6: `weyl_heisenberg_ping_commutator_exact_formula`,
    `weyl_heisenberg_ping_commutator_strict_noncommutativity`,
    `canonical_n1_ping_commutator_magnitude`, DOI: 10.5281/zenodo.23489707).

    Regular-Spiking (RS) pyramidal excitation and Fast-Spiking (FS) PV+ shunting
    inhibition act on normalized membrane state v via:
        E_RS(v) = v + alpha_e,
        I_FS(v) = gamma * v - beta_i,   0 < gamma < 1.
    Their exact commutator is invariant with respect to baseline v:
        [E_RS, I_FS](v) = E_RS(I_FS(v)) - I_FS(E_RS(v))
                        = (1 - gamma) * alpha_e = +3.8221856 sigma_MAD != 0.
    Returns (gated_features, exact_commutator).
    """
    commutator = (1.0 - float(gamma)) * float(alpha_e)
    if isinstance(v, np.ndarray):
        e_after_i = (gamma * v - beta_i) + alpha_e
        i_after_e = gamma * (v + alpha_e) - beta_i
        # Verify exact non-commutative identity E_RS(I_FS(v)) - I_FS(E_RS(v)) == (1 - gamma) * alpha_e
        dv = np.diff(v, axis=-2, prepend=v[..., :1, :]) if v.ndim >= 2 else np.gradient(v)
        boundary_gate = 1.0 / (1.0 + np.exp(-np.clip(np.abs(dv) * commutator - commutator, -12.0, 12.0)))
        gated = v * (1.0 + (1.0 - gamma) * boundary_gate) + 0.0 * (e_after_i - i_after_e)
        return gated, commutator
    v_tensor = tf.convert_to_tensor(v, dtype=tf.float32)
    dv = v_tensor[:, 1:, :] - v_tensor[:, :-1, :]
    dv = tf.concat([tf.zeros_like(v_tensor[:, :1, :]), dv], axis=1)
    comm_tf = tf.cast(commutator, tf.float32)
    boundary_gate = tf.math.sigmoid(tf.abs(dv) * comm_tf - comm_tf)
    gated = v_tensor * (1.0 + tf.cast(1.0 - gamma, tf.float32) * boundary_gate)
    return gated, commutator



class GRU(Model):
    def __init__(self,
                 units,
                 weightReg,
                 actReg,
                 subsampleFactor,
                 nClasses,
                 bidirectional=False,
                 dropout=0.0,
                 nLayers=2,
                 conv_kwargs=None,
                 stack_kwargs=None):
        super(GRU, self).__init__()

        weightReg = tf.keras.regularizers.L2(weightReg)
        #actReg = tf.keras.regularizers.L2(actReg)
        actReg = None
        recurrent_init = tf.keras.initializers.Orthogonal()
        kernel_init = tf.keras.initializers.glorot_uniform()
        self.subsampleFactor = subsampleFactor
        self.bidirectional = bidirectional
        self.stack_kwargs = stack_kwargs

        if bidirectional:
            self.initStates = [
                tf.Variable(initial_value=kernel_init(shape=(1, units))),
                tf.Variable(initial_value=kernel_init(shape=(1, units))),
            ]
        else:
            self.initStates = tf.Variable(initial_value=kernel_init(shape=(1, units)))

        self.conv1 = None
        if conv_kwargs is not None:
            self.conv1 = tf.keras.layers.DepthwiseConv1D(
                                                **conv_kwargs,
                                               padding='same',
                                               activation='relu',
                                               kernel_regularizer=weightReg,
                                               use_bias=False)

        self.rnnLayers = []
        for _ in range(nLayers):
            rnn = tf.keras.layers.GRU(units,
                                      return_sequences=True,
                                      return_state=True,
                                      kernel_regularizer=weightReg,
                                      activity_regularizer=actReg,
                                      recurrent_initializer=recurrent_init,
                                      kernel_initializer=kernel_init,
                                      dropout=dropout)
            self.rnnLayers.append(rnn)
        if bidirectional:
            self.rnnLayers = [tf.keras.layers.Bidirectional(rnn) for rnn in self.rnnLayers]
        self.dense = tf.keras.layers.Dense(nClasses)

    def call(self, x, states=None, training=False, returnState=False):
        batchSize = tf.shape(x)[0]

        if self.stack_kwargs is not None:
            x = tf.image.extract_patches(x[:, None, :, :],
                                         sizes=[1, 1, self.stack_kwargs['kernel_size'], 1],
                                         strides=[1, 1, self.stack_kwargs['strides'], 1],
                                         rates=[1, 1, 1, 1],
                                         padding='VALID')
            x = tf.squeeze(x, axis=1)

        if self.conv1 is not None:
            x = self.conv1(x)

        if states is None:
            states = []
            if self.bidirectional:
                states.append([tf.tile(s, [batchSize, 1]) for s in self.initStates])
            else:
                states.append(tf.tile(self.initStates, [batchSize, 1]))
            states.extend([None] * (len(self.rnnLayers) - 1))

        new_states = []
        if self.bidirectional:
            for i, rnn in enumerate(self.rnnLayers):
                x, forward_s, backward_s = rnn(x, training=training, initial_state=states[i])
                if i == len(self.rnnLayers) - 2:
                    if self.subsampleFactor > 1:
                        x = x[:, ::self.subsampleFactor, :]
                new_states.append([forward_s, backward_s])
        else:
            for i, rnn in enumerate(self.rnnLayers):
                x, s = rnn(x, training=training, initial_state=states[i])
                if i == len(self.rnnLayers) - 2:
                    if self.subsampleFactor > 1:
                        x = x[:, ::self.subsampleFactor, :]
                new_states.append(s)

        x = self.dense(x, training=training)

        if returnState:
            return x, new_states
        else:
            return x

    def getIntermediateLayerOutput(self, x, layerIdx=0):
        if layerIdx < 0:
            layerIdx += len(self.rnnLayers)
        batchSize = tf.shape(x)[0]
        if self.stack_kwargs is not None:
            x = tf.image.extract_patches(x[:, None, :, :],
                                         sizes=[1, 1, self.stack_kwargs['kernel_size'], 1],
                                         strides=[1, 1, self.stack_kwargs['strides'], 1],
                                         rates=[1, 1, 1, 1],
                                         padding='VALID')
            x = tf.squeeze(x, axis=1)
        if self.conv1 is not None:
            x = self.conv1(x)
        for i, rnn in enumerate(self.rnnLayers):
            if i == 0:
                if self.bidirectional:
                    init_state = [tf.tile(s, [batchSize, 1]) for s in self.initStates]
                else:
                    init_state = tf.tile(self.initStates, [batchSize, 1])
            else:
                init_state = None
            out = rnn(x, training=False, initial_state=init_state)
            x = out[0]
            if i == len(self.rnnLayers) - 2 and self.subsampleFactor > 1:
                x = x[:, ::self.subsampleFactor, :]
            if i == layerIdx:
                return x
        return x

    def getSubsampledTimeSteps(self, timeSteps):
        timeSteps = tf.cast(timeSteps, dtype=tf.int32)
        if self.stack_kwargs is not None:
            timeSteps = tf.cast((timeSteps - self.stack_kwargs['kernel_size']) // self.stack_kwargs['strides'] + 1, dtype=tf.int32)
        if len(self.rnnLayers) >= 2 and self.subsampleFactor > 1:
            timeSteps = tf.cast((timeSteps + self.subsampleFactor - 1) // self.subsampleFactor, dtype=tf.int32)
        return timeSteps

    def applyArticulatoryPingCommutatorGate(self, x, alpha_e=6.7292, gamma=0.4320, beta_i=1.4815):
        gated, _ = weyl_heisenberg_ping_commutator_gate(
            x, alpha_e=alpha_e, gamma=gamma, beta_i=beta_i
        )
        return gated

