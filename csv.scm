;;
;; 
;;  Routines for parsing and printing comma-separated values.
;;
;;  Based in part on RFC 4180, "Common Format and MIME Type for
;;  Comma-Separated Values (CSV) Files", and on the Haskell Text.CSV
;;  module by Jaap Weel.
;;
;;
;;  Differences with the RFC:
;;
;;   1) the RFC prescribes CRLF standard network line breaks, but many
;;   CSV files have platform-dependent line endings, so this library
;;   accepts any sequence of CRs and LFs as a line break.
;;
;;   2) The format of header lines is exactly like a regular record
;;   and the presence of a header can only be determined from the mime
;;   type.  available. This library treats all lines as regular
;;   records.
;;
;;   3) The formal grammar specifies that fields can contain only
;;   certain US ASCII characters, but the specification of the MIME
;;   type allows for other character sets. This library allows all
;;   characters in fields, except for the field delimiter character,
;;   CRs and LFs in unquoted fields. This should make it possible to
;;   parse CSV files in any encoding, but it allows for characters
;;   such as tabs that the RFC may be interpreted to forbid even in
;;   non-US-ASCII character sets.
;;
;;   4) According to the RFC, the records all have to have the same
;;   length. This library allows variable length records.
;;
;;   5) The delimiter character is specified by the user and can be
;;   a character other than comma, or an SRFI-14 character set.
;;
;;
;;   Copyright 2009-2018 Ivan Raikov
;;
;;   This program is free software: you can redistribute it and/or
;;   modify it under the terms of the GNU General Public License as
;;   published by the Free Software Foundation, either version 3 of
;;   the License, or (at your option) any later version.
;;
;;   This program is distributed in the hope that it will be useful,
;;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;   General Public License for more details.
;;
;;   A full copy of the GPL license can be found at
;;   <http://www.gnu.org/licenses/>.


(module csv

	(make-parser make-format csv-record?
         list->csv-record csv-record->list
         csv)
	
	(import scheme (chicken base) (chicken format) (chicken string)
                srfi-1 yasos yasos-collections
                (only utf8-srfi-13 string-concatenate)
                (only utf8-srfi-14 char-set-contains?  ucs-range->char-set string->char-set 
                      char-set? char-set char-set-union char-set-complement char-set-difference
                      char-set:full char-set:ascii)
                (only regex regexp regexp-escape string-search string-substitute* string-split-fields)
                
                (prefix abnf abnf:) 
                (prefix abnf-consumers abnf:) 
                )


(define-record-type csv-record 
  (list->csv-record elems)
  csv-record?
  (elems  csv-record->list))


(define (non-escaped delim)
    (abnf:bind-consumed->string
     (abnf:repetition
      (abnf:set
       (char-set-complement
	(char-set-union
	 (if (char? delim) (char-set delim) delim)
	 (string->char-set "\n\r\""))
	))
      ))
    )


(define escaped-dquote
  (abnf:lit "\"\""))


(define textdata
  (char-set-union
   (char-set-difference char-set:full char-set:ascii)
   (char-set-union (ucs-range->char-set #x20 #x22)
		   (ucs-range->char-set #x23 #x2D)
		   (ucs-range->char-set #x2D #x7F))))


(define (escaped delim)
  (abnf:concatenation
   (abnf:drop-consumed abnf:dquote)
   (abnf:bind-consumed->string
    (abnf:repetition 
     (abnf:alternatives
      escaped-dquote
      (abnf:set (char-set-union (if (char? delim) (char-set delim) delim) (char-set #\newline #\return)  textdata)))))
   (abnf:drop-consumed abnf:dquote)))


(define (field delim)
  (abnf:alternatives 
   (escaped delim)
   (non-escaped delim) 
   ))

  
(define  (record delim)
  (abnf:bind-consumed-strings->list 
   list->csv-record
   (abnf:concatenation
    (field delim)
    (abnf:repetition
     (abnf:concatenation
      (abnf:drop-consumed 
       (if (char? delim) (abnf:char delim) (abnf:set delim)))
      (field delim))))))


(define (csv delim)
  (abnf:repetition
   (abnf:concatenation 
    (record delim)
    (abnf:drop-consumed
     (abnf:repetition1 
      (abnf:set-from-string "\r\n"))))))


(define (check-delimiter d)
  (if (not (or (char? d) (char-set? d)))
      (error 'parser "delimiter is not a character or a character set"))
  (cond ((char? d)
	 (case d
	   ((#\newline #\return #\")
	    (error 
	     'parser
	     "delimiter character is one of newline, carriage return or quotation mark"))))
	((char-set? d)
	 (if (or (char-set-contains? d #\newline)
		 (char-set-contains? d #\return)
		 (char-set-contains? d #\"))
	    (error 
	     'parser
	     "delimiter character set includes newline, carriage return or quotation mark")))))

(define (err s)
  (print "CSV parser error on stream: " s)
  (list))
			 
(define (make-parser . rest)
  (let ((delimiter (if (null? rest) #\, (car rest))))
    (check-delimiter delimiter)
    (let ((p (csv delimiter)))
      (lambda (s)
        (p (compose reverse car) err `(() ,s))))))

    
(define rx-newline (regexp "[^\r\n]+"))

(define (normalise-newlines s) 
  (string-concatenate (intersperse (string-split-fields rx-newline s) "\r\n")))

(define rx-quote (regexp "\""))

(define (normalise-quotes s)  (string-substitute* s `((,rx-quote . "\"\""))))

(define (make-format-cell delimiter)
   (define special-strs
     (map (compose regexp-escape ->string) (list delimiter #\" #\newline #\return)))

   (define rx-special
     (regexp (string-concatenate (intersperse special-strs "|"))))

   (define (format-cell x)
     (let ([str (format "~A" x)])
        (if (string-search rx-special str)
	   (string-append "\"" (normalise-newlines (normalise-quotes str)) "\"")
	   str)))
   
   format-cell)


(define (make-format . rest)
  (let-optionals rest ((delimiter #\,))

   (define format-cell (make-format-cell delimiter))

   (define (format-record rec)
     (and (csv-record? rec)
	  (let ((ls (csv-record->list rec)))
	    (string-concatenate 
	     (intersperse (map format-cell ls) (->string delimiter))))))

   (define (format-csv ls)
     (and (pair? ls)
	  (string-concatenate
	   (append (intersperse (map format-record ls) "\r\n") 
		   (list "\r\n")))))


   (values format-cell format-record format-csv)))


)
