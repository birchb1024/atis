#!/usr/bin/env genyris
@ns date "http://www.genyris.org/lang/date#"
@ns sys  "http://www.genyris.org/lang/system#"
@ns u    "http://www.genyris.org/lang/utilities#"
@ns web  "http://www.genyris.org/lang/web#"

@ns ntfy 'http://ntfy.sh/api'

include 'ntfy.g'

var URL 'http://aussieadsb.com/airportinfo/'

var airport
    cond
        (> (length sys:argv) 1)
            (nth 1 sys:argv)
        else
            'YMML'

def remove-multiple-spaces ((Str = String)) # TODO replace this with a string function, maybe a regex (replace) or maybe split on '  ' and recombine with join
    var try (Str(.replace '  ' ' '))
    cond
        (equal? Str try)
            Str
        else
            remove-multiple-spaces try

def contains((S = String) (P = String))
    > (length (S(.split P))) 1

def handle-error(err airport)
    # maybe its down again
    var url (URL(.+ airport))
    catch another-error
        var response
            web:get ('%a/%a'(.format URL airport))
        print (list @LINE response)
        var page ((left response)(.readAll))
        cond
            (contains page 'Error retrieving NOTAMs')
                wall 'aussieadsb says "Error retrieving NOTAMs"'
    cond
        another-error
            ntfy:post 'ERROR' another-error
            stderr(.format '\nERRORS %s %s\n' err another-error)

def fetch-raw-atis(URL airport)
    var url (URL(.+ airport))
    var cmd ("curl -sS '%a%a' | tidy --doctype omit --add-xml-decl yes --output-xml yes -indent 2>/dev/null | xmllint --xpath \"//p[@class='monospace' and starts-with(text(), 'ATIS %a')]/text()\" - | tr '\n'  ' ' "(.format URL airport airport))
    var result nil
    catch (err bt)
        setq result (os!exec '/bin/bash' '-c' cmd)
        print (list @LINE result)
        cond
             (not (left result))
                handle-error err airport
    cond
        err
            handle-error err airport
    result


def pull-info (text)
    var result (graph)
    var id (intern (scale (/ (os!ticks) 1000) 0)) # e.g. 1752828247
    result
        .put id ^id id
        .put id ^gmt-date-time (date:format-date (os!ticks) 'dd MMM yyyy HH:mm:ss z' 'GMT')
        .put id ^local-date (date:format-date (os!ticks) 'dd MMM yyyy HH:mm:ss z' 'Australia/Melbourne')
        .put id ^raw-data text
    for pattern in atis-patterns
        var regularex (right pattern)
        var attribute (left pattern)
        var matches (text(.regex regularex))
        cond
            (equal? 2 (length matches))
                result(.put id attribute (nth 1 matches))
    result

var atis-patterns
    data
        airport-icao-code =   'ATIS +([A-Z]+) +[A-Z] +[0-9]+ +[A-Z]+:' # ATIS YMML V 140252
        atis-code = 'ATIS +[A-Z]+ ([A-Z]) [0-9]+ +[A-Z]+:' # ATIS YMML V 140252
        date-time = 'ATIS +[A-Z]+ [A-Z] ([0-9]+) +[A-Z]+:' # ATIS YMML V 140252

        approach = 'APCH: +([A-Z0-9 .]+) +[A-Z]+:' # APCH: EXP GLS OR ILS APCH
        runway = 'RWY: +([0-9RL]+) +[A-Z ]+:' # 'RWY: 27'
        runway-arrival = 'RWY: +([0-9RL]+) FOR ARR' # 'RWY: 27 FOR ARR'
        runway-arrival = 'RWY: +([0-9RL]+ AND +[0-9RL]+) FOR ARR.'  # RWY: 27 AND 34 FOR ARR.
        runway-departure = 'RWY +([0-9RL]+) FOR DEP ' # 'RWY 27 FOR DEP '
        runway-departure = 'RWY +([0-9RL]+) FOR DEPARTURES' # 'RWY 34 FOR DEPARTURES'
        runway-depart-via = 'RWY +[0-9RL]+ FOR DEPARTURES VIA ([ ,A-Z0-9]+)+RWY +[0-9]+' # 'RWY 34 FOR DEPARTURES VIA MNG NONIX, AND DOSEL, RWY 27
        runway-depart-other = 'RWY +([0-9RL]+) FOR ALL OTHER DEPARTURES' # 'RWY 27 FOR ALL OTHER DEPARTURES'
        runway-depart-other = 'RUNWAY +([0-9RL]+) FOR ALL OTHER OPERATIONS' # RUNWAY 27 FOR ALL OTHER OPERATIONS
        wind-min = 'WI?ND: +([0-9]+)+-[0-9]+/[0-9]+' # 'WND: 250-320/12'
        wind-max = 'WI?ND: +[0-9]+-([0-9]+)/[0-9]+'  # 'WND: 250-320/12'
        wind-speed = 'WI?ND: +[-0-9]+/([0-9]+)' # 'WND: 250/12'
        wind-direction = 'WI?ND: +([0-9]+)/[0-9]+' # 'WND: 250/12'
        visability = 'VIS: +([A-Z 0-9]+) +[A-Z]+:' # VIS: GREATER THAN 10 KM
        cloud = 'CLD: +([A-Z0-9, ]+) +[A-Z]+:' # CLD: SCT035
        temperature = 'TMP: +([0-9]+) +[A-Z]+:' # TMP: 12
        pressure-qnh = 'QNH: +([0-9]+)' # QNH: 1013
        operating-info = 'OPR INFO: +([A-Z0-9 ,.]+) +[A-Z]+:' # OPR INFO: ABN UNSERVICEABLE AS PER NOTAM '
        max-crosswind = 'MAX XW ([0-9]+) KTS' # MAX XW 15 KTS
        weather = 'WX: +([A-Z0-9., ]+) +[A-Z]+:' # WX: CAVOK
        runway-surface-condition = 'SFC COND: +([A-Z0-9., ]+) +[A-Z]+:' # SFC COND: RWY 27 SFC COND CODE 5, 5, 5. WHOLE RWY WET. RWY 34 SFC COND CODE 5, 5, 5. WHOLE RWY WET.
        weather-significant = 'SIGWX: +([A-Z0-9 ]+)' # SIGWX: MOD TURB FCST BLW 5000 FT

def fetch-and-parse (URL airport)
    var response (fetch-raw-atis URL airport)
    cond
        (null? (left response))
            ntfy:post 'ERROR' ('ERROR with %s %a%a'(.format response URL airport))
            stderr(.format 'ERROR %s\n' response)
            nil
        else
            decode response

def decode (response)
    var text (left (left response))
    setq text (text(.replace '+' ''))
    setq text  (remove-multiple-spaces text)
    pull-info text

def get-runways(info id properties)
    var result ()
    for P in properties
        var values (info(.get-list id P))
        cond
            values
                setq result
                    cons
                        cons P values
                        result
    result

def verbose(info)
    var Ps ()
    cond
        (> 1 (length (info(.subjects))))
            stderr(.format 'bad graph input to verbose %s' (info(.asTriples)))
            os!exit 1
    var ID (left (info(.subjects)))

    var buffer (Pipe!open 'verbose')
    var out-writer (buffer(.output))
    for T in (info(.asTriples))
        setq Ps (cons T!predicate Ps)
    for P in (sort Ps)
        #print (list @LINE ID P (info(.get-list ID P)))
       cond
        (not (equal? ^raw-data P))
            var O (info(.get ID P))
            out-writer
                .format "%a: %a\n" P O
    (buffer(.input))(.readAll)

def spam (topics msg)
    stderr(.format 'spam: %a\n' msg)
    for Topic in topics
        ntfy:post Topic msg

def wall (msg)
    spam ^('ERROR') msg #^('ERROR' 'RAW' 'RUNWAY' 'VERBOSE') # rate limited!

def main (airport)
    wall ('started %s'(.format @FILE))
    var code nil
    var runways nil

    def notify-if-atis-code-changed(info id)
        var new-code (info(.get id ^atis-code))
        print ('code %a %a %a'(.format @FILE @LINE new-code))
        cond
            (not (equal? code new-code))
                setq code new-code
                var V (verbose info)
                ntfy:post 'RAW' (info(.get id ^raw-data))
                ntfy:post 'VERBOSE' V
                display V

    def notify-if-runways-changed(info id)
        var new-runway (get-runways info id ^(runway runway-arrival runway-departure))
        print ('runways %a %a %a'(.format @FILE @LINE new-runway))
        cond
            (not (equal? runways new-runway))
                setq runways new-runway
                ntfy:post 'RUNWAY'
                    '%a runway %a\n\n%a'
                        .format
                            ~ (info(.get id ^atis-code))
                            ~ runways
                            ~ (info(.get id ^raw-data))

    while true
        var info (fetch-and-parse URL airport)
        cond
            info
                for T in (info(.asTriples))
                    print T
                var id (left (info(.subjects)))
                notify-if-atis-code-changed info id
                notify-if-runways-changed info id
        sleep (* 60 1000)

def sys:getopt (index default)
    cond
        (> (length sys:argv) index)
            (nth index sys:argv)
        else
            default

main (sys:getopt 1 'YMML')
