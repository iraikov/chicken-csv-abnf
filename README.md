csv-abnf
-------

### Description

The library contains procedures for parsing and formatting of
comma-separated values (CSV) as described in [RFC
4180](http://tools.ietf.org/html/rfc4180). There are several
differences with the RFC:

- The RFC prescribes CRLF standard network line breaks, but many CSV files have platform-dependent line endings, so this library accepts any sequence of CRs and LFs as a line break.
- The format of header lines is exactly like a regular record and the presence of a header can only be determined from the mime type. This library treats all lines as regular records.
-   The formal grammar specifies that fields can contain only certain US ASCII characters, but the specification of the MIME type allows for other character sets. This library allow all characters in fields, except for the field delimiter character, CRs and LFs in unquoted fields.
- According to the RFC, the records all have to have the same length. This library allows variable length records. 
- The delimiter character is specified by the user and can be a character other than comma, or an SRFI-14 character set.

### Library Procedures

<procedure>
(csv-record? X) =&gt; BOOL
</procedure>
Returns {{#t}} if the given object is a csv record, {{#f}} otherwise.

<procedure>
(list-&gt;csv-record LIST) =&gt; CSV-RECORD
</procedure>
Takes in a list of values and creates a object.

<procedure>
(csv-record-&gt;list CSV-RECORD) =&gt; LIST
</procedure>
Returns the list of values contained in the given object.

#### Parsing Procedures: 

<procedure>
(csv-parser \[DELIMITER\]) =&gt; PARSER
</procedure>
When invoked, returns a parser procedure takes in a list of characters
and returns a list of the form:

 ((<#csv-record (FIELD1 FIELD2 ...)>) (<#csv-record ... >))

where represents the field values in a record.

Optional argument DELIMITER is the field delimiter character, if other than
comma.

<procedure>
(make-parser CSV-INSTANCE) =&gt; (LAMBDA \[DELIMITER\]) =&gt; PARSER
</procedure>

Once applied to an instance of the {{<CSV>}} typeclass, returns a
constructor for the CSV parsing procedure. Optional argument specifies
the field delimiter (comma by default). can be a character, or an
SRFI-14 character set. The returned procedure takes in an input stream
and returns a list of the form:

#### Formatting procedures

<procedure>
(make-format \[DELIMITER\]) =&gt; FORMAT-CELL \* FORMAT-RECORD \* FORMAT-CSV
</procedure>

Returns procedures for outputting individual field values, CSV records,
and lists of CSV records, where each list is printed on a separate line.

Procedure takes in a value, obtains its string representation via , and
surrounds the string with quotes, if it contains characters that need to
be escaped (such as quote characters, the delimiter character, or
newlines).

Procedure takes in a record of type and returns its string
representation, based on the strings produced by and the delimiter
character.

Procedure takes in a list of objects and produces a string
representation using .

Example:

```scheme
(import csv-abnf)

(define-values (fmt-cell fmt-record fmt-csv) (make-format “;”))

(fmt-cell “hello”) =&gt; “hello”

; This is quoted because it contains delimiter-characters

(fmt-cell “one;two;three”) =&gt; “\\”one;two;three\\""

; This is quoted because it contains quotes, which are then doubled for escaping

(fmt-cell “say \\”hi\\"") =&gt; “\\”say \\“\\”hi\\“\\”\\""

; Converts one line at a time (useful when converting data in a streaming manner)

(fmt-record (list-&gt;csv-record '(“hi there” “let's say \\”hello
world\\" again" “until we are bored”))) =&gt; “hi there;\\”let's say
\\“\\”hello world\\“\\” again\\“;until we are bored”

; And an example of how to quickly convert a list of lists\
; to a CSV string containing the entire CSV file

(fmt-csv (map list-&gt;csv-record
```

### Author

 Copyright 2009-2019 Ivan Raikov
