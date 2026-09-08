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
;;   Copyright 2009-2026 Ivan Raikov
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


(module csv-abnf

	(make-parser make-format csv-record?
         list->csv-record csv-record->list
         csv
         bi-field bi-record bi-csv)

	(import scheme (chicken base) (chicken format)
                srfi-1
                (only utf8-srfi-14 char-set-contains?  ucs-range->char-set string->char-set
                      char-set? char-set char-set-union char-set-complement char-set-difference
                      char-set:full char-set:ascii char-set->list)

                (prefix abnf abnf:)
                (prefix abnf-consumers abnf:)
                abnf-lens
                (prefix lexgen lex:)
                )


(define-record-type csv-record
  (list->csv-record elems)
  csv-record?
  (elems  csv-record->list))

;; A row to be printed can be given either as a csv-record or as a bare
;; list of field values.

(define (csv-row->list row) (if (csv-record? row) (csv-record->list row) row))


;; Character sets shared by both directions of the grammar: the set of
;; characters a non-escaped field may contain (everything except the
;; delimiter, CR, LF and the quote character), and the set of characters
;; that may appear literally (unescaped) inside a quoted field.

(define (delim-char-set delim)
  (if (char? delim) (char-set delim) delim))

(define (non-escaped-char-set delim)
  (char-set-complement
   (char-set-union (delim-char-set delim) (string->char-set "\n\r\""))))

(define textdata
  (char-set-union
   (char-set-difference char-set:full char-set:ascii)
   (char-set-union (ucs-range->char-set #x20 #x22)
		   (ucs-range->char-set #x23 #x2D)
		   (ucs-range->char-set #x2D #x7F))))

(define (escaped-content-char-set delim)
  (char-set-union (delim-char-set delim) (char-set #\newline #\return) textdata))

;; A field needs quoting on output exactly when it contains a character
;; that could not otherwise be told apart from field/record structure:
;; the delimiter, a quote character, or a line ending.

(define (field-needs-quoting? delim s)
  (let ((special (char-set-union (delim-char-set delim)
                                 (char-set #\" #\newline #\return))))
    (any (lambda (c) (char-set-contains? special c)) (string->list s))))

;; A literal "" inside a quoted field stands for one quote character; the
;; bidirectional dual of the old escaped-dquote, following the same
;; "fixed spelling that still carries a value" shape as abnf-lens's own
;; bi-drop-char/bi-drop-lit.

(define bi-escaped-dquote
  (bi-iso (lambda (flat) #\")
          (lambda (v) (and (char? v) (char=? v #\") '()))
          (bi-drop-lit "\"\"")))

(define (bi-non-escaped delim)
  (bi-iso
   (lambda (chars) (list->string chars))
   (lambda (s) (and (string? s) (string->list s)))
   (bi-repetition (bi-set (non-escaped-char-set delim)))))

(define (bi-escaped delim)
  (bi-iso
   (lambda (chars) (list->string chars))
   (lambda (s) (and (string? s) (field-needs-quoting? delim s) (string->list s)))
   (bi-seq (bi-drop-char #\")
           (bi-seq (bi-repetition
                    (bi-alternatives bi-escaped-dquote (bi-set (escaped-content-char-set delim))))
                   (bi-drop-char #\")))))

(define (bi-field delim)
  (bi-alternatives (bi-escaped delim) (bi-non-escaped delim)))

;; A delimiter can be a single character or an SRFI-14 character set, any
;; of which is accepted as the separator on parse; bi-drop-set is the
;; "drop"-style counterpart of bi-set for that case, printing one
;; representative member of the set.

(define (bi-drop-set s)
  (make-bp
   (lex:drop (abnf:set s))
   (lambda (vals) (cons (list (car (char-set->list s))) vals))))

(define (bi-drop-delim delim)
  (if (char? delim) (bi-drop-char delim) (bi-drop-set delim)))

(define (bi-record delim)
  (bi-iso
   (lambda (flat) (list->csv-record flat))
   (lambda (v) (and (or (csv-record? v) (list? v)) (csv-row->list v)))
   (bi-seq (bi-field delim)
           (bi-repetition (bi-seq (bi-drop-delim delim) (bi-field delim))))))

;; Records are separated by one or more CRs/LFs; the exact separator
;; consumed on parse is not preserved, so the printer always emits the
;; canonical CRLF, the same way abnf-lens's own
;; bi-drop-crlf/bi-drop-lwsp print a fixed canonical spelling for a
;; dropped rule.

(define bi-drop-line-ending
  (make-bp
   (lex:drop (abnf:repetition1 (abnf:set-from-string "\r\n")))
   (lambda (vals) (cons (list #\return #\newline) vals))))

(define (bi-csv delim)
  (bi-iso
   (lambda (flat) flat)
   (lambda (v) (and (list? v) v))
   (bi-repetition (bi-seq (bi-record delim) bi-drop-line-ending))))

;; One-directional parser combinator.

(define (csv delim) (bp-parser (bi-csv delim)))


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
    (let ((p (bi-csv delimiter)))
      (lambda (s)
        (let ((r (bp-parse p (if (string? s) s (list->string s)) err)))
          (if (pair? r) (car (car r)) r))))))


(define (make-format-cell delimiter)
  (let ((fld (bi-field delimiter)))
    (lambda (x) (bp-print fld (format "~A" x)))))


(define (make-format . rest)
  (let-optionals rest ((delimiter #\,))

   (define format-cell (make-format-cell delimiter))

   (define rec-bp (bi-csv delimiter))
   (define single-rec-bp (bi-record delimiter))

   (define (stringify-record row)
     (map (lambda (x) (format "~A" x)) (csv-row->list row)))

   (define (format-record row)
     (and (or (csv-record? row) (list? row))
	  (bp-print single-rec-bp (stringify-record row))))

   (define (format-csv ls)
     (and (pair? ls)
	  (bp-print rec-bp (map stringify-record ls))))


   (values format-cell format-record format-csv)))


)
