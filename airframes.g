#!/usr/bin/env genyris
@ns date "http://www.genyris.org/lang/date#"
@ns sys "http://www.genyris.org/lang/system#"
@ns u   "http://www.genyris.org/lang/utilities#"
@ns web "http://www.genyris.org/lang/web#"

var data-directory 'data/airframes'

var files
    (File!new data-directory)
        .list

for F in files
    print F
