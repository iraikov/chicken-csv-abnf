;; input stream based on character list

(import scheme (chicken base) test csv)

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

(test-exit)
