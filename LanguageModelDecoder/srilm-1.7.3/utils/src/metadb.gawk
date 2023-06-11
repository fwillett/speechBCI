#!/usr/local/bin/gawk -f
#
# metadb --
#	access the META-DB
#
# These files are subject to the SRILM Community Research License Version
# 1.0 (the "License"); you may not use these files except in compliance
# with the License. A copy of the License is included in the SRILM root
# directory.  Software distributed under the License is distributed on an
# "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# See the License for the specific language governing rights and
# limitations under the License.  This software is Copyright (c) SRI
# International, 1995-2011.  All rights reserved.
#
# $Header: /home/srilm/CVS/srilm/utils/src/metadb.gawk,v 1.26 2011/11/26 06:22:34 stolcke Exp $
#

function do_defines() {
    # process all defines 
    for (d in defines) {
	gsub(d, defines[d]);
    }

    # remove leading and trailing whitespace from value
    sub("^[ 	]*", "");
    sub("[ 	]*$", "");
}

function print_error(msg) {
    print filename ", line " lineno ": " msg >> "/dev/stderr";
}

# process an included file
# return 1 is caller should quit reading, 0 if not
function process_config_file(file) {

    if (file in including) {
	print "metadb INCLUDE looping through " file >> "/dev/stderr";
	exit 2
    }
    including[file] = 1;

    if (trace_includes) {
	print "READING " file >> "/dev/stderr";
    }

    filename = file;
    lineno = 0;
    
    while ((status = (getline < file)) > 0) {

	lineno ++;

	# skip comments and empty lines
	if (NF == 0 || $1 ~ /^#/) {
	    continue;
	}

	if ($1 == "DEFINE") {
	    if (NF < 2) {
		print_error("incomplete DEFINE");
		exit 2;
	    } else {
		symbol = $2;

		$1 = $2 = "";
		do_defines();

		defines[symbol] = $0;
	    }
	} else if ($1 == "SDEFINE") {
	    if (NF < 2) {
		print_error("incomplete SDEFINE");
		exit 2;
	    } else {
		symbol = $2;

		$1 = $2 = "";
		do_defines();

		# run right-hand-side as command and use output as value
		$0 | getline defines[symbol];
		close($0);
	    }
	} else if ($1 == "MDEFINE") {
	    if (NF < 2) {
		print_error("incomplete MDEFINE");
		exit 2;
	    } else if (!recursive) {
		symbol = $2;

		$1 = $2 = "";

		# look up the right-hand-side as metadb key,
		# avoiding recursive invocations
		db_command = "metadb -recursive -config " config_file " " $0;
		if (debug) {
		    print "metadb: " symbol " mdefined by: " db_command  >> "/dev/stderr";
		}

		db_command | getline defines[symbol];
		close(db_command);
	    }
	} else if ($1 == "UNDEF") {
	    if (NF < 2) {
		print_error("incomplete UNDEF");
		exit 2;
	    } else {
		delete defines[$2];
	    }
	} else if ($1 == "INCLUDE") {
	    if (NF < 2) {
		print_error("missing INCLUDE filename");
		exit 1
	    } else {
		$1 = "";
		do_defines();

		if (! ($0 ~ /^\//)) {
			includefile = file;
			sub("[^/]*$", "", includefile);
			if (includefile) {
				includefile = includefile $0;
			} else {
				includefile = $0;
			}
		} else {
			includefile = $0;
		}
			
		if (process_config_file(includefile)) {
			close(file);
			delete including[file];
			return 1;
		}
		filename = file;

		if (trace_includes) {
		    print "READING " file >> "/dev/stderr";
		}
	    }
	} else if ($1 == "ALIAS") {
	    if (NF != 3 || $2 == $3) {
		print_error("illegal ALIAS");
		exit 2
	    }

	    if (dump_values) print $0;

	    if ($2 == key) {
		if (debug) {
		    print "metadb: " key " redirected to " $3 >> "/dev/stderr";
		}

		# close all currently read files so they can be read again
		# from the top
		for (f in including) {
		    close(f)
		}

		# forget all current file inclusions
		delete including;

		key = $3;
		return process_config_file(config_file);
	    }
	} else if ($1 == "ALIAS_SUFFIX") {
	    if (NF != 3 || $2 == $3) {
		print_error("illegal ALIAS_SUFFIX");
		exit 2
	    }

	    if (dump_values) print $0;

	    suffix_len = length($2);
	    key_len = length(key);
	    key_prefix = substr(key, 1, key_len-suffix_len);

	    if ($2 == substr(key, key_len-suffix_len+1) && !index(key_prefix, "_")) {
		# close all currently read files so they can be read again
		# from the top
		for (f in including) {
		    close(f)
		}

		# forget all current file inclusions
		delete including;

		old_key = key;
		key = key_prefix $3;

		if (debug) {
		    print "metadb: " old_key " redirected to " key >> "/dev/stderr";
		}

		return process_config_file(config_file);
	    }
	} else if ($1 == key || dump_values) {
	    this_key = $1;
	    $1 = "";
	    do_defines();

	    if ($0 == "__END__") {
		if (dump_values) {
		    have_keys[this_key] = 1;
		    continue;
		} else {
		    close(file);
		    delete including[file];
		    return 1;
		}
	    }

	    if (query_mode) {
		exit 0;
	    } else if (dump_values) {
		# when dumping all keys, output the first key value found
		if (!(this_key in have_keys)) {
		    print this_key, $0;
		    if (!all_values) {
			have_keys[this_key] = 1;
		    }
		}
	    } else {
		if (debug) {
		    print "metadb: " key "=" $0 >> "/dev/stderr";
		}

		if (!error_mode || $0 != "") {
		    key_found = 1;
		    print;
		}
	    }

	    if (!all_values && !dump_values) {
		close(file);
		delete including[file];
		return 1;
	    }
	}
    }
    if (status < 0) {
	print "error reading " file >> "/dev/stderr";
	exit 2;
    }
    close(file);
    delete including[file];
    return 0;
}

function print_usage() {
    print "usage: metadb [-options ...] key1 [key2 ...]";
    print "-q           query mode -- check if key is defined";
    print "-e           exit with error message if key is undefined";
    print "-all         return multiple key values";
    print "-dump        dump all key and values";
    print "-includes	list included files";
    print "-config FILE set config file (default $" db_config ")";
}

BEGIN {
    key = "";
    all_values = 0;
    dump_values = 0;
    trace_includes = 0;
    recursive = 0;
    db_config = "METADB_CONFIG";
    config_file = "";
    query_mode = 0;
    error_mode = 0;
    debug = ENVIRON["METADB_DEBUG"];
    
    for (i = 1; i < ARGC ; i ++) {
	if (ARGV[i] == "-q") {
	    query_mode = 1;
	} else if (ARGV[i] == "-e") {
	    error_mode = 1;
	} else if (ARGV[i] == "-all") {
	    all_values = 1;
	} else if (ARGV[i] == "-dump") {
	    dump_values = 1;
	} else if (ARGV[i] == "-includes") {
	    trace_includes = 1;
	} else if (ARGV[i] == "-recursive") {
	    recursive = 1;
	} else if (ARGV[i] == "-config") {
	    config_file = ARGV[i + 1];
	    i ++; 
	} else if (ARGV[i] == "-help") {
	    print_usage();
	    exit 0;
	} else if (ARGV[i] ~ /^-/) {
	    print "unknown option: " ARGV[i] >> "/dev/stderr";
	    exit 2;
	} else {
	    break;
	}
    }

    if (!config_file) {
	if (db_config in ENVIRON) {
	    config_file = ENVIRON[db_config];
	} else {
	    print db_config " not defined" >> "/dev/stderr";
	    exit 1;
	}
    }

    if (config_file == "") {
	print "empty config file name" >> "/dev/stderr";
	exit 1;
    }

    if (dump_values) {	
	key = "";
	process_config_file(config_file);
    } 

    for ( ; i < ARGC ; i ++) {
	key = ARGV[i];

	key_found = 0;
	process_config_file(config_file);

        if (error_mode && !key_found) {
	    print "key \"" key "\" empty or not defined in " config_file \
								>> "/dev/stderr";
	    exit 1;
	}
    }

    if (query_mode) {
        # we only get here if nothing was found, so return with error
	exit 1;
    }
}

