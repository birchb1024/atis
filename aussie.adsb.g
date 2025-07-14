#!/usr/bin/env genyris
@ns u   "http://www.genyris.org/lang/utilities#"
@ns web "http://www.genyris.org/lang/web#"
@ns date "http://www.genyris.org/lang/date#"

def url-entity-remove(S)
    S
        (.replace '&#xA;' '')
            (.replace '&#x9;' '')
                .replace '&#x2B;' '+'

def url-entity-expand(S)
    S
        (.replace '&#xA;' ' END ')
            (.replace '&#x9;' '')
                .replace '&#x2B;' '+'

def epoch-seconds() (scale (/ (os!ticks) 1000) 0)



def parse(Fd airport)
    var result ()
    def log (info)
        setq result
            cons
                list airport info
                result
    for Line in Fd
        var Tokens (Line(.regex '(^[\\s]*<div>)([^<]*)(</div>).*$'))
        cond
            Tokens
                #stderr(.format '%a' (url-entity-expand Line))
                var No-junk (url-entity-expand (nth 2 Tokens))
                var clean
                    No-junk
                        .split(' +')
                cond
                    (equal? airport (left clean))
                        log clean
    result



var URL 'http://aussieadsb.com/airportinfo/'

def parse-atis-line (L accumulator)
    var tokens (L(.split ' '))
    stderr(.format '%a %s\n' @LINE tokens)
    parse-atis-tokens tokens accumulator

def parse-atis-tokens (tokens accumulator)
    cond
        (< (length tokens) 2)
            stderr(.format 'WARNING skipping short line %s %s\n' (> 1 (length tokens)) tokens)
        (equal? '+' (nth 0 tokens))
            parse-atis-tokens (right tokens) accumulator
        (equal? 'ATIS' (nth 0 tokens))
            var version (intern (nth 2 tokens))
            accumulator(.put version ^airport (nth 1 tokens))
            accumulator(.put version ^date (nth 3 tokens))
        (equal? 'RWY:' (nth 0 tokens))
            var version (left (accumulator(.subjects)))
            #print (list @LINE version)
            accumulator(.put version ^runway (nth 1 tokens))
        (or (equal? 'WND:' (nth 0 tokens)) (equal? 'WIND:' (nth 0 tokens)))
            #stderr(.format 'WIND line %s\n' tokens)
            var version (left (accumulator(.subjects)))
            accumulator(.put version ^wind-direction (left ((nth 1 tokens)(.split '/'))))
            accumulator(.put version ^wind-gusts (nth 1 ((nth 1 tokens)(.split '/'))))
    #print (list @LINE (accumulator(.asTriples)))


def predicates(G  S)
    var preds ()
    var G2 (G(.select S nil nil))
    for T in (G2(.asTriples))
        setq preds
            cons
                (T(.predicate))
                preds
    (sort preds)

def fetch-raw-atis(URL airport)
    var info (graph)
    var url ('http://aussieadsb.com/airportinfo/'(.+ airport))
    var cmd ("curl -sS 'http://aussieadsb.com/airportinfo/%a' | tidy --doctype omit --add-xml-decl yes --output-xml yes -indent 2>/dev/null | xmllint --xpath \"//p[@class='monospace' and starts-with(text(), 'ATIS %a')]/text()\" -"(.format airport airport))
    #print (list @LINE url cmd)
    var result nil
    catch (err bt)
        setq result (os!exec '/bin/bash' '-c' cmd)
        #print @LINE result
        scan-lines info (left result)
    cond
        err
            stderr(.format '\nERROR %s\nBACKTRACE %s\n' err bt)
    info

def scan-lines(info Lines)
    #print @LINE Lines
    for l in Lines
        var L
            l(.regex '(^ *)(.+)')
        cond
            L
                parse-atis-line (nth 2 L) info
    var version (left (info(.subjects)))
    info
        .put version ^name version
        .put version ^epoch-seconds (epoch-seconds)
        .put version ^gmt-date-time (date:format-date (os!ticks) 'dd MMM yyyy HH:mm:ss z' 'GMT')
        .put version ^local-date (date:format-date (os!ticks) 'dd MMM yyyy HH:mm:ss z' 'Australia/Melbourne')
    info

var previous-info (graph)

while true
    var new-info (fetch-raw-atis URL 'YMML')
    #print (list @LINE  (new-info(.subjects)) (previous-info(.subjects)) (equal? (new-info(.subjects)) (previous-info(.subjects))))
    cond
        (equal? 0 (new-info(.length)))
            stderr(.format 'X')
        (not (equal? (new-info(.subjects)) (previous-info(.subjects))))
            setq previous-info new-info
            #print @LINE (new-info(.asTriples))
            for T in (new-info(.asTriples))
                print T
            stderr(.format '.')
    sleep (* 60 1000)

# $ curl -sS 'http://aussieadsb.com/airportinfo/YMML' | tidy --doctype omit --add-xml-decl yes --output-xml yes -indent 2>/dev/null | xmllint --xpath "//p[@class='monospace' and starts-with(text(), 'ATIS YMML')]/text()" -
# ATIS YMML W 130450
#                    APCH: EXP GLS OR RNP APCH
#                    RWY: 34
#                    OPR INFO: ALL DEPARTURES MUST REQUEST PUSH BACK
#                   ON 127.2
#                    + WND: 350/15-30
#                    VIS: GREATER THAN 10 KM
#                    CLD: FEW035
#                    + TMP: 15
#                    + QNH: 1007
#                    + SIGWX: ML SIGMET ZULU 07 VALID, FORECASTING
#                   SEV TURB BELOW 7000
#                    FT.


# Refer
#
## https://stackoverflow.com/a/21480078
## https://www.baeldung.com/linux/evaluate-xpath#using-the-xmllint-command
## https://blog.apify.com/xpath-contains/

