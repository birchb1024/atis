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
    def log (data)
        setq result
            cons
                list airport data
                result
    for Line in Fd
        var Tokens (Line(.regex '(^[\\s]*<div class="atis">)([^<]*)(</div>).*$'))
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

def fetch-n-parse(URL airport)
    var Response (web:get URL)
    var Fd (left Response)
    var result (parse Fd airport)
    result


def diff(A B)
    cond
        (not (is-instance? A Pair))
            var same (equal? A B)
            cond
                (not same)
                    stderr(.format 'difference: %s %s\n' A B)
            same

        (is-instance? A Pair)
            and
                diff (left A) (left B)
                diff (right A) (right B)


var previous nil
while true
    stderr(.format '. %s\n' (date:format-date (os!ticks) 'dd MMM yyyy HH:mm:ss z' 'GMT'))
    var current
        fetch-n-parse 'https://atis.guru/atis/YMML' 'YMML'
    cond
        (not (equal? previous current))
            stderr
                .format '%s %s %s\n' @LINE
                    diff previous current
                    equal? previous current
            setq previous current
            u:format '%s\n'
                list
                    epoch-seconds
                    date:format-date (os!ticks) 'dd MMM yyyy HH:mm:ss z' 'GMT'
                    ~ current
    sleep 600000
