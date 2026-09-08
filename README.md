# csv-abnf

## Description

The library contains procedures for parsing and formatting of
comma-separated values (CSV) as described in [RFC
4180](http://tools.ietf.org/html/rfc4180). There are several
differences with the RFC:

- The RFC prescribes CRLF standard network line breaks, but many CSV files have platform-dependent line endings, so this library accepts any sequence of CRs and LFs as a line break.
- The format of header lines is exactly like a regular record and the presence of a header can only be determined from the mime type. This library treats all lines as regular records.
- The formal grammar specifies that fields can contain only certain US ASCII characters, but the specification of the MIME type allows for other character sets. This library allow all characters in fields, except for the field delimiter character, CRs and LFs in unquoted fields.
- According to the RFC, the records all have to have the same length. This library allows variable length records.
- The delimiter character is specified by the user and can be a character other than comma, or an SRFI-14 character set.

The grammar is built with the
[abnf](http://wiki.call-cc.org/eggref/6/abnf) egg's `abnf-lens`
component, which makes every rule *bidirectional*: the same rule both
parses text into values and prints values back out as text. This means
`make-parser` and `make-format` are guaranteed to agree with each
other, and the underlying bidirectional rules (`bi-field`,
`bi-record`, `bi-csv`) are also exported directly, which then allows
embedding CSV parsing/printing inside a larger `abnf-lens` grammar.

## Library Procedures

### `(csv-record? x)` -> boolean

Returns `#t` if the given object is a csv record, `#f` otherwise.

### `(list->csv-record list)` -> csv-record

Takes in a list of values and creates a csv-record object.

### `(csv-record->list csv-record)` -> list

Returns the list of values contained in the given object.

## Parsing procedures

### `(make-parser [delimiter])` -> parser

Returns a parser procedure. Optional argument `delimiter` is the field
delimiter (comma by default); it can be a character, or an SRFI-14
character set. The returned procedure takes a string (or, for
backwards compatibility, a list of characters) and returns a list of
csv-record objects, one per record:

```
(<#csv-record (FIELD1 FIELD2 ...)> <#csv-record ...> ...)
```

## Formatting procedures

### `(make-format [delimiter])` -> format-cell, format-record, format-csv

Returns procedures for outputting individual field values, CSV records,
and lists of CSV records, where each record is printed on a separate
line.

`format-cell` takes a value, obtains its string representation via
`format`'s `~A` directive, and surrounds the string with quotes if it
contains characters that need to be escaped (such as quote characters,
the delimiter character, or newlines).

`format-record` takes a row and returns its string representation,
based on the strings produced by `format-cell` and the delimiter
character. A row can be given either as a bare list of field values,
or as a csv-record (e.g. one obtained back from `make-parser`) — there
is no need to wrap a plain list with `list->csv-record` before printing
it.

`format-csv` takes a list of rows (each a bare list or a csv-record;
the two can be freely mixed) and produces a string representation using
`format-record`, with a trailing CRLF after every record.

Example:

```scheme
(import csv-abnf)

(define-values (fmt-cell fmt-record fmt-csv) (make-format #\;))

(fmt-cell "hello") ;; => "hello"

;; This is quoted because it contains the delimiter character
(fmt-cell "one;two;three") ;; => "\"one;two;three\""

;; This is quoted because it contains quotes, which are then doubled for escaping
(fmt-cell "say \"hi\"") ;; => "\"say \"\"hi\"\"\""

;; Rows are plain lists -- no list->csv-record wrapping needed
(fmt-record (list "hi there" "let's say \"hello world\" again" "until we are bored"))
;; => "hi there;\"let's say \"\"hello world\"\" again\";until we are bored"

;; And an example of how to quickly convert a list of lists
;; to a CSV string containing the entire CSV file
(fmt-csv (list (list "a" "b") (list "c" "d")))
;; => "a;b\r\nc;d\r\n"

;; csv-record objects (e.g. rows just read back with make-parser) work
;; directly too, with no unwrap/rewrap step:
(fmt-csv (map list->csv-record (list (list "a" "b") (list "c" "d"))))
;; => "a;b\r\nc;d\r\n"
```

## Bidirectional grammar rules

These are the `abnf-lens` `bp` ("bidirectional parser") values that
`make-parser`/`make-format` are built from. They can be used directly
with `bp-parse`/`bp-print` (from the `abnf-lens` egg component), for
example to embed CSV data inside a larger bidirectional grammar.

### `(bi-field delimiter)` -> bp

A single field: a string, quoted only when it needs to be (i.e. when it
contains the delimiter, a quote character, a CR or a LF).

### `(bi-record delimiter)` -> bp

One record: a csv-record whose fields are separated by `delimiter`,
with no trailing line ending.

### `(bi-csv delimiter)` -> bp

A whole CSV file: a list of csv-record objects, each followed by a
line ending.

```scheme
(import csv-abnf abnf-lens)

;; bp-parse returns (list (list matched-value) remaining-stream);
;; (car (car ...)) unwraps it to the list of csv-records.
(car (car (bp-parse (bi-csv #\,) "a,b\r\nc,d\r\n" (lambda (s) (error "parse failed" s)))))
;; => (list (list->csv-record '("a" "b")) (list->csv-record '("c" "d")))

(bp-print (bi-csv #\,) '(("a" "b") ("c" "d")))
;; => "a,b\r\nc,d\r\n"
```

## License

>
> Copyright 2009-2026 Ivan Raikov
> 
> This program is free software: you can redistribute it and/or modify
> it under the terms of the GNU General Public License as published by
> the Free Software Foundation, either version 3 of the License, or (at
> your option) any later version.
> 
> This program is distributed in the hope that it will be useful, but
> WITHOUT ANY WARRANTY; without even the implied warranty of
> MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
> General Public License for more details.
> 
> A full copy of the GPL license can be found at
> <http://www.gnu.org/licenses/>.
