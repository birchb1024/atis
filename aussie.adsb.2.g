#!/usr/bin/env genyris
@ns u   "http://www.genyris.org/lang/utilities#"
@ns web "http://www.genyris.org/lang/web#"
@ns date "http://www.genyris.org/lang/date#"
@ns sys "http://www.genyris.org/lang/system#"

var URL 'http://aussieadsb.com/airportinfo/'

var airport
    cond
        (> (length sys:argv) 1)
            (nth 1 sys:argv)
        else
            'YMML'

def remove-multiple-spaces ((S = String))
    var try (S(.replace '  ' ' '))
    cond
        (equal? S try)
            S
        else
            remove-multiple-spaces try



def fetch-raw-atis(URL airport)
    var url ('http://aussieadsb.com/airportinfo/'(.+ airport))
    var cmd ("curl -sS 'http://aussieadsb.com/airportinfo/%a' | tidy --doctype omit --add-xml-decl yes --output-xml yes -indent 2>/dev/null | xmllint --xpath \"//p[@class='monospace' and starts-with(text(), 'ATIS %a')]/text()\" - | tr '\n'  ' ' "(.format airport airport))
    #print (list @LINE url cmd)
    var result nil
    catch (err bt)
        setq result (os!exec '/bin/bash' '-c' cmd)
        #print (list @LINE result)
    cond
        err
            stderr(.format '\nERROR %s\nBACKTRACE %s\n' err bt)
    result


def pull-info (text)
    var result (graph)
    var subject (os!ticks)
    for pattern in atis-patterns
        var regularex (right pattern)
        var attribute (left pattern)
        var matches (text(.regex regularex))
        cond
            (equal? 2 (length matches))
                result(.put subject attribute (nth 1 matches))
    cons subject result

var atis-patterns
    data
        airport-icao-code =   'ATIS +([A-Z]+) +[A-Z] +[0-9]+ +[A-Z]+:' # ATIS YMML V 140252
        atis-code = 'ATIS +[A-Z]+ ([A-Z]) [0-9]+ +[A-Z]+:' # ATIS YMML V 140252
        date-time = 'ATIS +[A-Z]+ [A-Z] ([0-9]+) +[A-Z]+:' # ATIS YMML V 140252

        approach = 'APCH: +([A-Z0-9 .]+) +[A-Z]+:' # APCH: EXP GLS OR ILS APCH
        runway = 'RWY: +([0-9RL]+) +[A-Z ]+:' # 'RWY: 27'
        runway-arrival = 'RWY: +([0-9RL]+) FOR ARR' # 'RWY: 27 FOR ARR'
        runway-departure = 'RWY +([0-9RL]+) FOR DEPARTURES' # 'RWY 34 FOR DEPARTURES'
        runway-depart-via = 'RWY +[0-9RL]+ FOR DEPARTURES VIA ([ ,A-Z0-9]+)+RWY +[0-9]+' # 'RWY 34 FOR DEPARTURES VIA MNG NONIX, AND DOSEL, RWY 27
        runway-depart-other = 'RWY +([0-9RL]+) FOR ALL OTHER DEPARTURES' # 'RWY 27 FOR ALL OTHER DEPARTURES'
        wind-min = 'WI?ND: +([0-9]+)+-[0-9]+/[0-9]+' # 'WND: 250-320/12'
        wind-max = 'WI?ND: +[0-9]+-([0-9]+)/[0-9]+'  # 'WND: 250-320/12'
        wind-speed = 'WI?ND: +[-0-9]+/([0-9]+)' # 'WND: 250/12'
        wind = 'WI?ND: +([0-9]+)/[0-9]+' # 'WND: 250/12'
        visability = 'VIS: +([A-Z 0-9]+) +[A-Z]+:' # VIS: GREATER THAN 10 KM
        cloud = 'CLD: +([A-Z0-9, ]+) +[A-Z]+:' # CLD: SCT035
        temperature = 'TMP: +([0-9]+) +[A-Z]+:' # TMP: 12
        pressure-qnh = 'QNH: +([0-9]+)' # QNH: 1013
        operating-info = 'OPR INFO: +([A-Z0-9 ,.]+) +[A-Z]+:' # INFO: ABN UNSERVICEABLE AS PER NOTAM '
        max-crosswind = 'MAX XW ([0-9]+) KTS' # MAX XW 15 KTS
        weather = 'WX: +([A-Z0-9., ]+) +[A-Z]+:' # WX: CAVOK

def fetch-and-parse (URL airport)
    var response (fetch-raw-atis URL airport)
    cond
        (null? (left response))
            stderr(.format '%s\n' response)
            #os!exit 2
    var text (left (left response))
    setq text (text(.replace '+' ''))
    setq text  (remove-multiple-spaces text)

    stderr(.format '%s\n' text)
    pull-info text


var URL 'http://aussieadsb.com/airportinfo/'

var airport
    cond
        (> (length sys:argv) 1)
            (nth 1 sys:argv)
        else
            'YMML'

var code ''
while true
    var data (fetch-and-parse URL airport)
    var S (left data)
    var G (right data)
    var new-code (G(.get S ^atis-code))
    cond
        (not (equal? code new-code))
            setq code new-code
            for T in (G(.asTriples))
                print T
    sleep (* 60 1000)
