
(import scheme (chicken base) test csv-abnf abnf-lens)

(define pcsv (make-parser #\|))
(define-values (fcell _ fcsv) (make-format #\|))

(define (->char-list s)
  (if (string? s) (string->list s) s))

(let ((res (pcsv (->char-list "\"Test \n1\"|Test 2|Test 3\nTest 4|Test 5\n"))))
  (print (map csv-record->list res)))

(test-group "csv parse test"
	    (test
	     `(,(list->csv-record (list "Test \n1" "Test 2" "Test 3"))
	       ,(list->csv-record (list "Test 4" "Test 5" )))
	     (pcsv (->char-list "\"Test \n1\"|Test 2|Test 3\nTest 4|Test 5\n"))))


(test-group "csv format test"
	    (test
	     "Test 1|Test 2|Test 3\r\nTest 4|Test 5\r\n"
	     (fcsv `(,(list->csv-record (list "Test 1" "Test 2" "Test 3"))
		     ,(list->csv-record (list "Test 4" "Test 5" ))))))

(test-group "csv roundtrip"
            (test '(("foo\"bar") ("o'baz"))
                  (map csv-record->list (pcsv
                                         (->char-list (fcsv `(,(list->csv-record (list "foo\"bar"))
                                                              ,(list->csv-record (list "o'baz" ))))
                                                      ))
                       ))
            )

(test-group "csv bidirectional grammar"
            (test "unquoted field is printed without quotes"
                  "hello"
                  (bp-print (bi-field #\|) "hello"))

            (test "field containing the delimiter is quoted"
                  "\"a|b\""
                  (bp-print (bi-field #\|) "a|b"))

            (test "field containing a quote character is quoted and doubled"
                  "\"say \"\"hi\"\"\""
                  (bp-print (bi-field #\|) "say \"hi\""))

            (test "bi-field round-trips print then parse"
                  "a|b"
                  (car (car (bp-parse (bi-field #\|) (bp-print (bi-field #\|) "a|b")
                                       (lambda (s) (list 'parse-error s))))))

            (test "bi-csv round-trips a whole file, print then parse"
                  '(("Test 1" "Test 2" "Test 3") ("Test 4" "Test 5"))
                  (map csv-record->list
                       (car (car (bp-parse (bi-csv #\|)
                                            (bp-print (bi-csv #\|)
                                                      (list (list->csv-record (list "Test 1" "Test 2" "Test 3"))
                                                            (list->csv-record (list "Test 4" "Test 5"))))
                                            (lambda (s) (list 'parse-error s)))))))

            (test-group "exact round-trip fidelity for embedded newlines"
                        (test "a bare embedded newline round-trips exactly, without CRLF normalisation"
                              "one\ntwo"
                              (car (car (bp-parse (bi-field #\|)
                                                   (bp-print (bi-field #\|) "one\ntwo")
                                                   (lambda (s) (list 'parse-error s)))))))
            )

(test-group "csv write interface accepts bare lists directly"
            (test "bp-print on bi-record accepts a bare list, no csv-record wrapping needed"
                  "Test 1|Test 2|Test 3"
                  (bp-print (bi-record #\|) (list "Test 1" "Test 2" "Test 3")))

            (let-values (((_ frecord fcsv2) (make-format #\|)))
              (test "format-record: bare list produces the same output as list->csv-record"
                    (frecord (list->csv-record (list "Test 1" "Test 2" "Test 3")))
                    (frecord (list "Test 1" "Test 2" "Test 3")))

              (test "format-csv: bare lists produce the same output as list->csv-record"
                    (fcsv2 (list (list->csv-record (list "Test 1" "Test 2" "Test 3"))
                                 (list->csv-record (list "Test 4" "Test 5"))))
                    (fcsv2 (list (list "Test 1" "Test 2" "Test 3")
                                 (list "Test 4" "Test 5"))))

              (test "format-csv: a bare-list row and a csv-record row can be mixed in the same call"
                    "Test 1|Test 2|Test 3\r\nTest 4|Test 5\r\n"
                    (fcsv2 (list (list "Test 1" "Test 2" "Test 3")
                                 (list->csv-record (list "Test 4" "Test 5")))))
              )
            )
(test-exit)
