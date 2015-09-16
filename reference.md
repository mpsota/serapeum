# Function Listing For Serapeum (27 files, 239 functions)

- [Macro Tools](#macro-tools)
- [Types](#types)
- [Definitions](#definitions)
- [Binding](#binding)
- [Control Flow](#control-flow)
- [Threads](#threads)
- [Iter](#iter)
- [Conditions](#conditions)
- [Op](#op)
- [Functions](#functions)
- [Trees](#trees)
- [Hash Tables](#hash-tables)
- [Files](#files)
- [Symbols](#symbols)
- [Arrays](#arrays)
- [Queue](#queue)
- [Box](#box)
- [Vectors](#vectors)
- [Numbers](#numbers)
- [Octets](#octets)
- [Time](#time)
- [Clos](#clos)
- [Hooks](#hooks)
- [Fbind](#fbind)
- [Lists](#lists)
- [Strings](#strings)
- [Sequences](#sequences)

## Macro Tools

### `(string-gensym x)`

Equivalent to (gensym (string x)).

Generally preferable to calling GENSYM with a string, because it
respects the current read table.

The alternative to writing `(mapcar (compose #'gensym #'string) ...)'
in every other macro.

[View source](macro-tools.lisp#L49)

### `(unsplice form)`

If FORM is non-nil, wrap it in a list.

This is useful with ,@ in macros, and with `mapcan`.

From Lparallel.

[View source](macro-tools.lisp#L63)

### `(with-thunk (var &rest args) &body body)`

A macro-writing macro for the `call-with-` style.

In the `call-with-` style of writing macros, the macro is simply a
syntactic convenience that wraps its body in a thunk and a call to the
function that does the actual work.

    (defmacro with-foo (&body body)
      `(call-with-foo (lambda () ,@body)))

The `call-with-` style has many advantages. Functions are easier to
write than macros; you can change the behavior of a function without
having to recompile all its callers; functions can be traced, appear
in backtraces, etc.

But meanwhile, all those thunks are being allocated on the heap. Can
we avoid this? Yes, but at a high cost in boilerplate: the closure has
to be given a name (using `flet`) so it can be declared
`dynamic-extent`.

    (defmacro with-foo (&body body)
      (with-gensyms (thunk)
        `(flet ((,thunk () ,@body))
           (declare (dynamic-extent #',thunk))
           (call-with-foo #',thunk))))

`with-thunk` avoids the boilerplate:

    (defmacro with-foo (&body body)
      (with-thunk (body)
        `(call-with-foo ,body)))

It is also possible to construct a "thunk" with arguments.

    (with-thunk (body foo)
      `(call-with-foo ,body))
    ≡ `(flet ((,thunk (,foo)
          ,@body))
        (declare (dynamic-extent #',thunk))
        (call-with-foo #',thunk))

Needs a better name.

[View source](macro-tools.lisp#L76)

### `(expand-macro form &optional env)`

Like `macroexpand-1`, but also expand compiler macros.
From Swank.

[View source](macro-tools.lisp#L132)

### `(expand-macro-recursively form &optional env)`

Like `macroexpand`, but also expand compiler macros.
From Swank.

[View source](macro-tools.lisp#L141)

### `(partition-declarations xs declarations &optional env)`

Split DECLARATIONS into those that do and do not apply to XS.
Return two values, one with each set.

Both sets of declarations are returned in a form that can be spliced
directly into Lisp code:

     (locally ,@(partition-declarations vars decls) ...)

[View source](macro-tools.lisp#L154)

### `(callf function place &rest args)`

Set PLACE to the value of calling FUNCTION on PLACE, with ARGS.

[View source](macro-tools.lisp#L206)

### `(callf2 function arg1 place &rest args)`

Like CALLF, but with the place as the second argument.

[View source](macro-tools.lisp#L215)

### `(define-do-macro name binds &body body)`

Define an iteration macro like `dolist`.

Writing a macro like `dolist` is more complicated than it looks. For
consistency with the rest of CL, you have to do all of the following:

- The entire loop must be surrounded with an implicit `nil` block.
- The body of the loop must be an implicit `tagbody`.
- There must be an optional `return` form which, if given, supplies
  the values to return from the loop. While this return form is
  being evaluated, the iteration variables are bound to `nil`.

Say you wanted to define a `do-hash` macro that iterates over hash
tables. A full implementation would look like this:

     (defmacro do-hash ((key value hash-table &optional return) &body body)
       (multiple-value-bind (body decls) (parse-body body)
         `(block nil
            (maphash (lambda (,key ,value)
                       ,@decls
                       (tagbody
                          ,@body))
                     ,hash-table)
            ,(when return
               `(let (,key ,value)
                  ,return)))))

Using `define-do-macro` takes care of all of this for you.

     (define-do-macro do-hash ((key value hash-table &optional return) &body body)
       `(maphash (lambda (,key ,value)
                   ,@body)
                 ,hash-table))

[View source](macro-tools.lisp#L224)

### `(define-post-modify-macro name lambda-list function &optional documentation)`

Like `define-modify-macro`, but arranges to return the original value.

[View source](macro-tools.lisp#L282)

## Types

### `(-> function args values)`

Declaim the ftype of a function from ARGS to VALUES.

     (-> mod-fixnum+ (fixnum fixnum) fixnum)
     (defun mod-fixnum+ (x y) ...)

[View source](types.lisp#L10)

### `(assure type-spec &body (form))`

Macro for inline type checking.

`assure` is to `the` as `check-type` is to `declare`.

     (the string 1) => undefined
     (assure string 1) => error

The value returned from the `assure` form is guaranteed to satisfy
TYPE-SPEC. If FORM does not return a value of that type, then a
correctable error is signaled. You can supply a value of the correct
type with the `use-value` restart.

Note that the supplied value is *not* saved into the place designated
by FORM. (But see `assuref`.)

From ISLISP.

[View source](types.lisp#L48)

### `(assuref place type-spec)`

Like `(progn (check-type PLACE TYPE-SPEC) PLACE)`, but evaluates
PLACE only once.

[View source](types.lisp#L67)

## Definitions

### `(def var &body (&optional val (doc nil docp)))`

The famous "deflex".

Define a top level (global) lexical VAR with initial value VAL,
which is assigned unconditionally as with DEFPARAMETER. If a DOC
string is provided, it is attached to both the name |VAR| and the name
*STORAGE-FOR-DEFLEX-VAR-|VAR|* as a documentation string of kind
'VARIABLE. The new VAR will have lexical scope and thus may be
shadowed by LET bindings without affecting its dynamic (global) value.

It is possible for VAL to close over VAR.

In implementations that support it (SBCL and CCL, at the moment) this
version creates a backing variable that is "global" or "static",
so there is not just a change in semantics, but also a gain in
efficiency.

The original `deflex` is due to Rob Warnock.

[View source](definitions.lisp#L8)

### `(defconst symbol init &optional docstring)`

Define a constant, lexically.

`defconst` defines a constant using a strategy similar to `def`, so
you don’t have to +cage+ your constants.

The constant is only redefined on re-evaluation if INIT has a
different literal representation than the old value.

The name is from Emacs Lisp.

[View source](definitions.lisp#L64)

### `(defsubst name params &body body)`

Define an inline function.

     (defsubst fn ...)
     ≡ (declaim (inline fn))
       (defun fn ...)

The advantage of a separate defining form for inline functions is that
you can't forget to declaim the function inline before defining it –
without which it may not actually end up being inlined.

From Emacs and other ancient Lisps.

[View source](definitions.lisp#L88)

### `(defalias alias &body (def &optional docstring))`

Define a value as a top-level function.

     (defalias string-gensym (compose #'gensym #'string))

Like (setf (fdefinition ALIAS) DEF), but with a place to put
documentation and some niceties to placate the compiler.

Name from Emacs Lisp.

[View source](definitions.lisp#L110)

### `(defplace name args &body (form &optional docstring))`

Define NAME and (SETF NAME) in one go.

Note that the body must be a single, setf-able expression.

[View source](definitions.lisp#L136)

### `(defcondition name supers &body (slots &rest options))`

Alias for `define-condition`.

Like (define-condition ...), but blissfully conforming to the same
nomenclatural convention as every other definition form in Common
Lisp.

[View source](definitions.lisp#L148)

### `(local &body orig-body)`

Make internal definitions using top-level definition forms.

Within `local` you can use top-level definition forms and have them
create purely local definitions, like `let`, `labels`, and `macrolet`:

     (fboundp 'plus) ; => nil

     (local
       (defun plus (x y)
         (+ x y))
       (plus 2 2))
     ;; => 4

     (fboundp 'plus) ; => nil

Each form in BODY is subjected to partial expansion (with
`macroexpand-1`) until either it expands into a recognized definition
form (like `defun`) or it can be expanded no further.

(This means that you can use macros that expand into top-level
definition forms to create local definitions.)

Just as at the real top level, a form that expands into `progn` (or an
equivalent `eval-when`) is descended into, and definitions that occur
within it are treated as top-level definitions.

(Support for `eval-when` is incomplete: `eval-when` is supported only
when it is equivalent to `progn`).

The recognized definition forms are:

- `def`, for lexical variables (as with `letrec`)
- `defun`, for local functions (as with `labels`)
- `defalias`, to bind values in the function namespace (like `fbindrec*`)
- `declaim`, to make declarations (as with `declare`)
- `defconstant` and `defconst`, which behave exactly like symbol macros

Also, with serious restrictions, you can use:

- `defmacro`, for local macros (as with `defmacro`)
- `define-symbol-macro`, to bind symbol macros (as with `symbol-macrolet`)

(Note that the top-level definition forms defined by Common Lisp
are (necessarily) supplemented by two from Serapeum: `def` and
`defalias`.)

The exact order in which the bindings are made depends on how `local`
is implemented at the time you read this. The only guarantees are that
variables are bound sequentially; functions can always close over the
bindings of variables, and over other functions; and macros can be
used once they are defined.

     (local
       (def x 1)
       (def y (1+ x))
       y)
     => 2

     (local
       (defun adder (y)
         (+ x y))
       (def x 2)
       (adder 1))
     => 3

Perhaps surprisingly, `let` forms (as well as `let*` and
`multiple-value-bind`) *are* descended into; the only difference is
that `defun` is implicitly translated into `defalias`. This means you
use the top-level idiom of wrapping `let` around `defun`.

    (local
      (let ((x 2))
        (defun adder (y)
          (+ x y)))
      (adder 2))
    => 4

Support for macros is sharply limited.

1. Macros and symbol macros must precede all other expressions.

2. Macros and symbol macros cannot be defined inside of binding forms
like `let`.

3. `symbol-macrolet` and `macrolet` are not allowed at the top level
of a `local` form.

These restrictions are undesirable, but well justified: it is
impossible to handle the general case both correctly and portably, and
while some special cases could be provided for, the cost in complexity
of implementation and maintenance would be prohibitive.

The value returned by the `local` form is that of the last form in
BODY. Note that definitions have return values in `local` just like
they do at the top level. For example:

     (local
       (plus 2 2)
       (defun plus (x y)
         (+ x y)))

Returns `plus`, not 4.

The `local` macro is loosely based on Racket's support for internal
definitions.

[View source](definitions.lisp#L161)

## Binding

### `(lret (&rest bindings) &body body)`

Return the initial value of the last binding in BINDINGS. The idea
is to create something, initialize it, and then return it.

    (lret ((x 1)
           (y (make-array 1)))
      (setf (aref y 0) x))
    => #(1)

`lret` may seem trivial, but it fufills the highest purpose a macro
can: it eliminates a whole class of bugs (initializing an object, but
forgetting to return it).

Cf. `aprog1` in Anaphora.

[View source](binding.lisp#L4)

### `(lret* (&rest bindings) &body body)`

Cf. `lret`.

[View source](binding.lisp#L25)

### `(letrec (&rest bindings) &body body)`

Recursive LET.
The idea is that functions created in BINDINGS can close over one
another, and themselves.

Note that `letrec` only binds variables: it can define recursive
functions, but can't bind them as functions. (But see `fbindrec`.)

[View source](binding.lisp#L41)

### `(letrec* (&rest bindings) &body body)`

Like LETREC, but the bindings are evaluated in order.
See Waddell et al., *Fixing Letrec* for motivation.

Cf. `fbindrec*`.

[View source](binding.lisp#L52)

### `(mvlet* (&rest bindings) &body body)`

Expand a series of nested `multiple-value-bind` forms.

`mvlet*` is similar in intent to Scheme’s `let-values`, but with a
different and less parenthesis-intensive syntax. Each binding is a
list of

    (var var*... expr)

A simple example should suffice to show both the implementation and
the motivation:

    (defun uptime (seconds)
      (mvlet* ((minutes seconds (truncate seconds 60))
               (hours minutes (truncate minutes 60))
               (days hours (truncate hours 24)))
        (declare ((integer 0 *) days hours minutes seconds))
        (fmt "~d day~:p, ~d hour~:p, ~d minute~:p, ~d second~:p"
             days hours minutes seconds)))

Note that declarations work just like `let*`.

[View source](binding.lisp#L69)

### `(mvlet (&rest bindings) &body body)`

Parallel (`let`-like) version of `mvlet*`.

[View source](binding.lisp#L127)

### `(and-let* (&rest clauses) &body body)`

Scheme's guarded LET* (SRFI-2).

Each clause should have one of the following forms:

- `identifier`, in which case IDENTIFIER's value is tested.

- `(expression)`, in which case the value of EXPRESSION is tested.

- `(identifier expression)' in which case EXPRESSION is evaluated,
    and, if its value is not false, IDENTIFIER is bound to that value
    for the remainder of the clauses and the optional body.

Note that, of course, the semantics are slightly different in Common
Lisp than in Scheme, because our AND short-circuits on null, not
false.

[View source](binding.lisp#L161)

## Control Flow

### `(eval-and-compile &body body)`

Emacs's `eval-and-compile`.

Shorthand for
        (eval-when (:compile-toplevel :load-toplevel :execute) ...)

[View source](control-flow.lisp#L3)

### `(no x)`

Another alias for `not` and `null`.

From Arc.

[View source](control-flow.lisp#L11)

### `(nor &rest forms)`

Equivalent to (not (or ...)).

From Arc.

[View source](control-flow.lisp#L20)

### `(nand &rest forms)`

Equivalent to (not (and ...)).

[View source](control-flow.lisp#L31)

### `(typecase-of type x &body clauses)`

Like `etypecase-of`, but may, and must, have an `otherwise` clause
in case X is not of TYPE.

[View source](control-flow.lisp#L110)

### `(etypecase-of type x &body body)`

Like `etypecase` but, at compile time, warn unless each clause in
BODY is a subtype of TYPE, and the clauses in BODY form an exhaustive
partition of TYPE.

[View source](control-flow.lisp#L123)

### `(case-of type x &body clauses)`

Like `case` but may, and must, have an `otherwise` clause 

[View source](control-flow.lisp#L135)

### `(ecase-of type x &body body)`

Like `ecase` but, given a TYPE (which should be defined as `(member
...)`), warn, at compile time, unless the keys in BODY are all of TYPE
and, taken together, they form an exhaustive partition of TYPE.

[View source](control-flow.lisp#L147)

### `(ctypecase-of type keyplace &body body)`

Like `etypecase-of`, but providing a `store-value` restart to correct KEYPLACE and try again.

[View source](control-flow.lisp#L159)

### `(ccase-of type keyplace &body body)`

Like `ecase-of`, but providing a `store-value` restart to correct KEYPLACE and try again.

[View source](control-flow.lisp#L164)

### `(case-using pred keyform &body clauses)`

ISLISP's case-using.

     (case-using #'eql x ...)
     ≡ (case x ...).

Note that, no matter the predicate, the keys are not evaluated. (But see `selector`.)

This version supports both single-item clauses (x ...) and
multiple-item clauses ((x y) ...), as well as (t ...) or (otherwise
...) for the default clause.

[View source](control-flow.lisp#L169)

### `(string-case stringform &body cases)`

Efficient `case`-like macro with string keys.

This uses Paul Khuong's `string-case` macro internally.

[View source](control-flow.lisp#L228)

### `(string-ecase stringform &body cases)`

Efficient `ecase`-like macro with string keys.

Cf. `string-case`.

[View source](control-flow.lisp#L236)

### `(econd &rest clauses)`

Like `cond`, but signal an error of type `econd-failure` if no
clause succeeds.

[View source](control-flow.lisp#L255)

### `(cond-let var &body clauses)`

Cross between COND and LET.

     (cond-let x ((test ...)))
     ≡ (let (x)
         (cond ((setf x test) ...)))

Cf. `acond` in Anaphora.

[View source](control-flow.lisp#L261)

### `(econd-let symbol &rest clauses)`

Like `cond-let` for `econd`.

[View source](control-flow.lisp#L282)

### `(cond-every &body clauses)`

Like `cond`, but instead of stopping after the first clause that
succeeds, run all the clauses that succeed.

Return the value of the last successful clause.

If a clause begins with `cl:otherwise`, it runs only if no preceding
form has succeeded.

Note that this does *not* do the same thing as a series of `when`
forms: `cond-every` evaluates *all* the tests *before* it evaluates
any of the forms.

From Zetalisp.

[View source](control-flow.lisp#L295)

### `(bcond &rest clauses)`

Scheme's extended COND.

This is exactly like COND, except for clauses having the form

     (test :=> recipient)

In that case, if TEST evaluates to a non-nil result, then RECIPIENT, a
function, is called with that result, and the result of RECIPIENT is
return as the value of the `cond`.

As an extension, a clause like this:

     (test :=> var ...)

Can be used as a shorthand for

     (test :=> (lambda (var) ...))

The name `bcond` for a “binding cond” goes back at least to the days
of the Lisp Machines. I do not know who was first to use it, but the
oldest examples I have found are by Michael Parker and Scott L.
Burson.

[View source](control-flow.lisp#L328)

### `(case-let (var expr) &body cases)`

Like (let ((VAR EXPR)) (case VAR ...))

[View source](control-flow.lisp#L381)

### `(ecase-let (var expr) &body cases)`

Like (let ((VAR EXPR)) (ecase VAR ...))

[View source](control-flow.lisp#L387)

### `(comment &body body)`

A macro that ignores its body and does nothing. Useful for
comments-by-example.

Also, as noted in EXTENSIONS.LISP of 1992, "This may seem like a
silly macro, but used inside of other macros or code generation
facilities it is very useful - you can see comments in the (one-time)
macro expansion!"

[View source](control-flow.lisp#L393)

### `(example &body body)`

Like `comment`.

[View source](control-flow.lisp#L403)

### `(nix place)`

Set PLACE to nil and return the old value of PLACE.

This may be more efficient than (shiftf place nil), because it only
sets PLACE when it is not already null.

[View source](control-flow.lisp#L407)

### `(ensure place &body newval)`

Essentially (or place (setf place newval)).

PLACE is treated as unbound if it returns `nil`, signals
`unbound-slot`, or signals `unbound-variable`.

Note that ENSURE is `setf`-able, so you can do things like
     (incf (ensure x 0))

Cf. `ensure2`.

[View source](control-flow.lisp#L422)

### `(ensure2 place &body newval)`

Like `ensure`, but specifically for accessors that return a second
value like `gethash`.

[View source](control-flow.lisp#L454)

### `(~> needle &rest holes)`

Threading macro from Clojure (by way of Racket).

Thread NEEDLE through HOLES, where each hole is either a
symbol (equivalent to `(hole needle)`) or a list (equivalent to `(hole
needle args...)`).

As an extension, an underscore in the argument list is replaced with
the needle, so you can pass the needle as an argument other than the
first.

[View source](control-flow.lisp#L521)

### `(~>> needle &rest holes)`

Like `~>` but, by default, thread NEEDLE as the last argument
instead of the first.

[View source](control-flow.lisp#L535)

### `(nest &rest things)`

Like ~>>, but backward.

This is useful when layering `with-x` macros where the order is not
important, and extra indentation would be misleading.

For example:

    (nest
     (with-open-file (in file1 :direction input))
     (with-open-file (in file2 :direction output))
     ...)

Is equivalent to:

    (with-open-file (in file1 :direction input)
      (with-open-file (in file2 :direction output)
        ...))

From UIOP, based on a suggestion by Marco Baringer.

[View source](control-flow.lisp#L542)

### `(select keyform &body clauses)`

Like `case`, but with evaluated keys.

Note that, like `case`, `select` interprets a list as the first
element of a clause as a list of keys. To use a form as a key, you
must add an extra set of parentheses.

     (select 2
       ((+ 2 2) t))
     => T

     (select 4
       (((+ 2 2)) t))
     => T

From Zetalisp.

[View source](control-flow.lisp#L567)

### `(selector keyform fn &body clauses)`

Like `select`, but compare using FN.

Note that (unlike `case-using`), FN is not evaluated.

From Zetalisp.

[View source](control-flow.lisp#L586)

## Threads

### `(synchronized (&optional (object nil objectp)) &body body)`

Run BODY holding a unique lock associated with OBJECT.
If no OBJECT is provided, run BODY as an anonymous critical section.

[View source](threads.lisp#L13)

### `(monitor object)`

Return a unique lock associated with OBJECT.

[View source](threads.lisp#L27)

## Iter

### `(nlet name (&rest bindings) &body body)`

Within BODY, bind NAME as a function, somewhat like LABELS, but
with the guarantee that recursive calls to NAME will not grow the
stack.

`nlet` resembles Scheme’s named let, and is used for the same purpose:
writing loops using tail recursion. You could of course do this with
`labels` as well, at least under some Lisp implementations, but `nlet`
guarantees tail call elimination anywhere and everywhere.

    (nlet rec ((i 1000000))
      (if (= i 0)
          0
          (rec (1- i))))
    => 0

Beware: because of the way it is written (literally, a GOTO with
arguments), `nlet` is limited: self calls must be tail calls. That is,
you cannot use `nlet` for true recursion.

The name comes from `Let Over Lambda', but this is a more careful
implementation: the function is not bound while the initial arguments
are being evaluated, and it is safe to close over the arguments.

[View source](iter.lisp#L21)

### `(with-collector (collector) &body body)`

Within BODY, bind COLLECTOR to a function of one argument that
accumulates all the arguments it has been called with in order, like
the collect clause in `loop`, finally returning the collection.

To see the collection so far, call COLLECTOR with no arguments.

Note that this version COLLECTOR to a closure, not a macro: you can
pass the collector around or return it like any other function.

[View source](iter.lisp#L100)

### `(collecting &body body)`

Like `with-collector`, with the collector bound to the result of
interning `collect` in the current package.

[View source](iter.lisp#L120)

### `(with-collectors (&rest collectors) &body body)`

Like `with-collector`, with multiple collectors.
Returns the final value of each collector as multiple values.

     (with-collectors (x y z)
       (x 1)
       (y 2)
       (z 3))
     => '(1) '(2) '(3)

[View source](iter.lisp#L127)

### `(summing &body body)`

Within BODY, bind `sum` to a function that gathers numbers to sum.

If the first form in BODY is a literal number, it is used instead of 0
as the initial sum.

To see the running sum, call `sum` with no arguments.

Return the total.

[View source](iter.lisp#L148)

## Conditions

### `(ignoring type &body body)`

An improved version of `ignore-errors`.

The behavior is the same: if an error occurs in the body, the form
returns two values, `nil` and the condition itself.

`ignoring` forces you to specify the kind of error you want to ignore:

    (ignoring parse-error
      ...)

I call it an improvement because I think `ignore-errors` is too broad:
by hiding all errors it becomes itself a source of bugs.

Of course you can still ignore all errors, at the cost of one extra
character:

    (ignoring error
      ...)

NB `(ignoring t)` is a bad idea.

[View source](conditions.lisp#L2)

### `(maybe-invoke-restart restart &rest values)`

When RESTART is active, invoke it with VALUES.

[View source](conditions.lisp#L28)

## Op

### `(op &body body)`

GOO's simple macro for positional lambdas.

An OP is like a lambda without an argument list. Within the body of the OP
form, an underscore introduces a new argument.

     (reduce (op (set-intersection _ _ :test #'equal))
             sets)

You can refer back to each argument by number, starting with _1.

     (funcall (op (+ _ _1)) 2) => 4

You can also use positional arguments directly:

     (reduce (op (funcall _2 _1)) ...)

Argument lists can be sparse:

     (apply (op (+ _1 _3 _5)) '(1 2 3 4 5)) => 9

Note that OP with a single argument is equivalent to CONSTANTLY:

     (funcall (op 1)) => 1

and that OP with a single placeholder is equivalent to IDENTITY:

     (funcall (op _) 1) => 1

OP can also be used to define variadic functions by using _* as the
placeholder. It is not necessary to use APPLY.

     (apply (op (+ _*)) '(1 2 3 4)) => 10

[View source](op.lisp#L16)

## Functions

### `(flip f)`

Flip around the arguments of a binary function.

That is, given a binary function, return another, equivalent function
that takes its two arguments in the opposite order.

From Haskell.

[View source](functions.lisp#L34)

### `(nth-arg n)`

Return a function that returns only its NTH argument, ignoring all others.

If you've ever caught yourself trying to do something like

    (mapcar #'second xs ys)

then `nth-arg` is what you need.

If `hash-table-keys` were not already defined by Alexandria, you could
define it thus:

    (defun hash-table-keys (table)
      (maphash-return (nth-arg 0) table))

[View source](functions.lisp#L50)

### `(distinct &key key test)`

Return a function that echoes only values it has not seen before.

    (defalias test (distinct))
    (test 'foo) => foo, t
    (test 'foo) => nil, nil

The second value is T when the value is distinct.

TEST must be a valid test for a hash table.

This has many uses, for example:

    (count-if (distinct) seq)
    ≡ (length (remove-duplicates seq))

[View source](functions.lisp#L75)

### `(throttle fn wait &key synchronized memoized)`

Wrap FN so it can be called no more than every WAIT seconds.
If FN was called less than WAIT seconds ago, return the values from the
last call. Otherwise, call FN normally and update the cached values.

WAIT, of course, may be a fractional number of seconds.

The throttled function is not thread-safe by default; use SYNCHRONIZED
to get a version with a lock.

You can pass MEMOIZED if you want the function to remember values
between calls.

[View source](functions.lisp#L101)

### `(juxt &rest fns)`

Clojure's `juxt`.

Return a function of one argument, which, in turn, returns a list
where each element is the result of applying one of FNS to the
argument.

It’s actually quite simple, but easier to demonstrate than to explain.
The classic example is to use `juxt` to implement `partition`:

    (defalias partition* (juxt #'filter #'remove-if))
    (partition* #'evenp '(1 2 3 4 5 6 7 8 9 10))
    => '((2 4 6 8 10) (1 3 5 7 9))

The general idea is that `juxt` takes things apart.

[View source](functions.lisp#L165)

### `(dynamic-closure symbols fn)`

Create a dynamic closure.

Some ancient Lisps had closures without lexical binding. Instead, you
could "close over" pieces of the current dynamic environment. When
the resulting closure was called, the symbols closed over would be
bound to their values at the time the closure was created. These
bindings would persist through subsequent invocations and could be
mutated. The result was something between a closure and a
continuation.

This particular piece of Lisp history is worth reviving, I think, if
only for use with threads. For example, to start a thread and
propagate the current value of `*standard-output*`:

     (bt:make-thread (dynamic-closure '(*standard-output*) (lambda ...)))
     = (let ((temp *standard-output*))
         (bt:make-thread
          (lambda ...
            (let ((*standard-output* temp))
              ...))))

[View source](functions.lisp#L195)

## Trees

### `(walk-tree fun tree &optional tag)`

Call FUN in turn over each atom and cons of TREE.

FUN can skip the current subtree with (throw TAG nil).

[View source](trees.lisp#L14)

### `(map-tree fun tree &optional tag)`

Walk FUN over TREE and build a tree from the results.

The new tree may share structure with the old tree.

     (eq tree (map-tree #'identity tree)) => T

FUN can skip the current subtree with (throw TAG SUBTREE), in which
case SUBTREE will be used as the value of the subtree.

[View source](trees.lisp#L35)

### `(leaf-walk fun tree)`

Call FUN on each leaf of TREE.

[View source](trees.lisp#L64)

### `(leaf-map fn tree)`

Call FN on each leaf of TREE.
Return a new tree possibly sharing structure with TREE.

[View source](trees.lisp#L75)

### `(occurs-if test tree &key key)`

Is there a node (leaf or cons) in TREE that satisfies TEST?

[View source](trees.lisp#L85)

### `(prune-if test tree &key key)`

Remove any atoms satisfying TEST from TREE.

[View source](trees.lisp#L95)

### `(occurs leaf tree &key key test)`

Is LEAF present in TREE?

[View source](trees.lisp#L110)

### `(prune leaf tree &key key test)`

Remove LEAF from TREE wherever it occurs.

[View source](trees.lisp#L115)

## Hash Tables

### `(dict &rest keys-and-values)`

A concise constructor for hash tables.

    (gethash :c (dict :a 1 :b 2 :c 3)) => 3, T

By default, return an 'equal hash table containing each successive
pair of keys and values from KEYS-AND-VALUES.

If the number of KEYS-AND-VALUES is odd, then the first argument is
understood as the test.

     (gethash "string" (dict "string" t)) => t
     (gethash "string" (dict 'eq "string" t)) => nil

[View source](hash-tables.lisp#L27)

### `(dict* dict &rest args)`

Merge new bindings into DICT.
Roughly equivalent to `(merge-tables DICT (dict args...))'.

[View source](hash-tables.lisp#L61)

### `(dictq &rest keys-and-values)`

A literal hash table.
Like `dict`, but the keys and values are implicitly quoted.

[View source](hash-tables.lisp#L68)

### `(href table &rest keys)`

A concise way of doings lookups in (potentially nested) hash tables.

    (href (dict :x 1) :x) => x
    (href (dict :x (dict :y 2)) :x :y)  => y

[View source](hash-tables.lisp#L73)

### `(href-default default table &rest keys)`

Like `href`, with a default.
As soon as one of KEYS fails to match, DEFAULT is returned.

[View source](hash-tables.lisp#L84)

### `(@ table key &rest keys)`

A concise way of doings lookups in (potentially nested) hash tables.

    (@ (dict :x 1) :x) => x
    (@ (dict :x (dict :y 2)) :x :y)  => y 

[View source](hash-tables.lisp#L122)

### `(pophash key hash-table)`

Lookup KEY in HASH-TABLE, return its value, and remove it.
From Zetalisp.

[View source](hash-tables.lisp#L151)

### `(swaphash key value hash-table)`

Set KEY and VALUE in HASH-TABLE, returning the old values of KEY.
From Zetalisp.

[View source](hash-tables.lisp#L159)

### `(hash-fold fn init hash-table)`

Reduce TABLE by calling FN with three values: a key from the hash
table, its value, and the return value of the last call to FN. On the
first call, INIT is supplied in place of the previous value.

From Guile.

[View source](hash-tables.lisp#L166)

### `(maphash-return fn hash-table)`

Like MAPHASH, but collect and return the values from FN.
From Zetalisp.

[View source](hash-tables.lisp#L179)

### `(merge-tables table &rest tables)`

Merge TABLE and TABLES, working from left to right.
The resulting hash table has the same parameters as TABLE.

Clojure's `merge`.

[View source](hash-tables.lisp#L190)

### `(flip-hash-table table &key test key)`

Return a table like TABLE, but with keys and values flipped.

     (gethash :y (flip-hash-table (dict :x :y)))
     => :x

TEST filters which keys to set. KEY defaults to `identity`.

[View source](hash-tables.lisp#L214)

### `(set-hash-table set &rest hash-table-args &key test key strict &allow-other-keys)`

Return SET, a list considered as a set, as a hash table.
This is the equivalent of Alexandria's `alist-hash-table` and
`plist-hash-table` for a list that denotes a set.

STRICT determines whether to check that the list actually is a set.

The resulting hash table has the elements of SET for both its keys and
values. That is, each element of SET is stored as if by
     (setf (gethash (key element) table) element)

[View source](hash-tables.lisp#L230)

### `(hash-table-set table &key strict test key)`

Return the set denoted by TABLE.
Given STRICT, check that the table actually denotes a set.

Without STRICT, equivalent to `hash-table-values`.

[View source](hash-tables.lisp#L259)

## Files

### `(path-join &rest pathnames)`

Build a pathname by merging from right to left.
With `path-join` you can pass the elements of the pathname being built
in the order they appear in it:

    (path-join (user-homedir-pathname) config-dir config-file)
    ≡ (merge-pathnames config-file (merge-pathnames config-dir (user-homedir-pathname)))

Note that `path-join` does not coerce the parts of the pathname into
directories; you have to do that yourself.

    (path-join "dir1" "dir2" "file") -> "file"
    (path-join "dir1/" "dir2/" "file") -> "dir1/dir2/file"

[View source](files.lisp#L2)

### `(write-stream-into-file stream pathname &key if-exists if-does-not-exist)`

Read STREAM and write the contents into PATHNAME.

STREAM will be closed afterwards, so wrap it with
`make-concatenated-stream` if you want it left open.

[View source](files.lisp#L21)

### `(file= file1 file2 &key buffer-size element-type)`

Compare FILE1 and FILE2 octet by octet, using buffers of
BUFFER-SIZE.

[View source](files.lisp#L35)

### `(file-size file &key element-type)`

The size of FILE, in bytes.

[View source](files.lisp#L53)

## Symbols

### `(find-keyword string)`

If STRING has been interned as a keyword, return it.

Like `make-keyword`, but preferable in most cases, because it doesn't
intern a keyword -- which is usually both unnecessary and unwise.

[View source](symbols.lisp#L4)

### `(bound-value s &optional default)`

If S is bound, return (values s t). Otherwise, return DEFAULT.

[View source](symbols.lisp#L17)

## Arrays

### `(array-index-row-major array row-major-index)`

The inverse of ARRAY-ROW-MAJOR-INDEX.

Given an array and a row-major index, return a list of subscripts.

     (apply #'aref (array-index-row-major i))
     ≡ (array-row-major-aref i)

[View source](arrays.lisp#L3)

### `(undisplace-array array)`

Recursively get the fundamental array that ARRAY is displaced to.

Return the fundamental array, and the start and end positions into it.

Borrowed from Erik Naggum.

[View source](arrays.lisp#L19)

## Queue

### `(queuep x)`

Is X a queue?

[View source](queue.lisp#L51)

### `(queue &rest initial-contents)`

Build a new queue with INITIAL-CONTENTS.

[View source](queue.lisp#L68)

### `(clear-queue queue)`

Return QUEUE's contents and reset it.

[View source](queue.lisp#L74)

### `(qlen queue)`

The number of items in QUEUE.

[View source](queue.lisp#L88)

### `(qlist queue)`

A list of the times in QUEUE.

[View source](queue.lisp#L93)

### `(enq item queue)`

Insert ITEM at end of QUEUE.

[View source](queue.lisp#L97)

### `(deq queue)`

Remove item from the front of the QUEUE.

[View source](queue.lisp#L106)

### `(front queue)`

The first element in QUEUE.

[View source](queue.lisp#L118)

### `(queue-empty-p queue)`

Is QUEUE empty?

[View source](queue.lisp#L122)

### `(qconc queue list)`

Destructively concatenate LIST onto the end of QUEUE.
Return the queue.

[View source](queue.lisp#L126)

## Box

### `(box value)`

Box a value.

[View source](box.lisp#L3)

### `(unbox x)`

The value in the box X.

[View source](box.lisp#L34)

## Vectors

### `(vect &rest initial-contents)`

Succint constructor for adjustable vectors with fill pointers.

    (vect 1 2 3)
    ≡ (make-array 3
            :adjustable t
            :fill-pointer 3
            :initial-contents (list 1 2 3))

The fill pointer is placed after the last element in INITIAL-CONTENTS.

[View source](vectors.lisp#L2)

### `(vector= v1 v2 &key test start1 end1 start2 end2)`

Like `string=` for any vector.

[View source](vectors.lisp#L36)

## Numbers

### `(finc ref &optional (delta 1))`

Like `incf`, but returns the old value instead of the new.

An alternative to using -1 as the starting value of a counter, which
can prevent optimization.

[View source](numbers.lisp#L2)

### `(fdec ref &optional (delta 1))`

Like `decf`, but returns the old value instead of the new.

[View source](numbers.lisp#L8)

### `(parse-float string &key start end junk-allowed type)`

Parse STRING as a float of TYPE.

The type of the float is determined by, in order:
- TYPE, if it is supplied;
- The type specified in the exponent of the string;
- `*read-default-float-format*`

     (parse-float "1.0") => 1.0s0
     (parse-float "1.0d0") => 1.0d0
     (parse-float "1.0s0" :type 'double-float) => 1.0d0

Of course you could just use `parse-number`, but sometimes only a
float will do.

[View source](numbers.lisp#L94)

### `(round-to number &optional divisor)`

Like `round`, but return the resulting number.

     (round 15 10) => 2
     (round-to 15 10) => 20

[View source](numbers.lisp#L133)

### `(bits int &key big-endian)`

Return a bit vector of the bits in INT.
Defaults to little-endian.

[View source](numbers.lisp#L140)

### `(unbits bits &key big-endian)`

Turn a sequence of BITS into an integer.
Defaults to little-endian.

[View source](numbers.lisp#L159)

### `(shrink n by)`

Decrease N by a factor.

[View source](numbers.lisp#L173)

### `(grow n by)`

Increase N by a factor.

[View source](numbers.lisp#L177)

### `(shrinkf g n)`

Shrink the value in a place by a factor.

[View source](numbers.lisp#L181)

### `(growf g n)`

Grow the value in a place by a factor.

[View source](numbers.lisp#L184)

### `(random-in-range low high)`

Random number in the range [low,high).

LOW and HIGH are automatically swapped if HIGH is less than LOW.

From Zetalisp.

[View source](numbers.lisp#L187)

## Octets

### `(octet-vector-p x)`

Is X an octet vector?

[View source](octets.lisp#L12)

### `(make-octet-vector size)`

Make an octet vector of SIZE elements.

[View source](octets.lisp#L17)

### `(octets n &key big-endian)`

Return N, an integer, as an octet vector.
Defaults to little-endian order.

[View source](octets.lisp#L24)

### `(unoctets bytes &key big-endian)`

Concatenate BYTES, an octet vector, into an integer.
Defaults to little-endian order.

[View source](octets.lisp#L43)

## Time

### `(universal-to-unix time)`

Convert a universal time to a Unix time.

[View source](time.lisp#L17)

### `(unix-to-universal time)`

Convert a Unix time to a universal time.

[View source](time.lisp#L21)

### `(get-unix-time)`

The current time as a count of seconds from the Unix epoch.

[View source](time.lisp#L25)

### `(date-leap-year-p year)`

Is YEAR a leap year in the Gregorian calendar?

[View source](time.lisp#L29)

### `(time-since time)`

Return seconds since TIME.

[View source](time.lisp#L36)

### `(time-until time)`

Return seconds until TIME.

[View source](time.lisp#L40)

### `(interval &key seconds minutes hours days weeks months years month-days year-days)`

A verbose but readable way of specifying intervals in seconds.

Intended as a more readable alternative to idioms
like (let ((day-in-seconds #.(* 24 60 60))) ...)

Has a compiler macro.

[View source](time.lisp#L44)

## Clos

### `(make class &rest initargs)`

Shorthand for `make-instance`.
After Eulisp.

[View source](clos.lisp#L2)

### `(class-name-safe x)`

The class name of the class of X.
If X is a class, the name of the class itself.

[View source](clos.lisp#L11)

### `(find-class-safe x)`

The class designated by X.
If X is a class, it designates itself.

[View source](clos.lisp#L18)

### `(defmethods class (self . slots) &body body)`

Concisely define methods that specialize on the same class.

You can use `defgeneric` to define methods on a single generic
function without having to repeat the name of the function:

    (defgeneric fn (x)
      (:method ((x string)) ...)
      (:method ((x number)) ...))

Which is equivalent to:

    (defgeneric fn (x))

    (defmethod fn ((x string))
      ...)

    (defmethod fn ((x number))
      ...)

Similarly, you can use `defmethods` to define methods that specialize
on the same class, and access the same slots, without having to
repeat the names of the class or the slots:

    (defmethods my-class (self x y)
      (:method initialize-instance :after (self &key)
        ...)
      (:method print-object (self stream)
        ...)
      (:method some-method ((x string) self)
        ...))

Which is equivalent to:

    (defmethod initialize-instance :after ((self my-class) &key)
      (with-slots (x y) self
        ...))

    (defmethod print-object ((self my-class) stream)
      (with-slots (x y) self
        ...))

    (defmethod some-method ((x string) (self my-class))
      (with-slots (y) self              ;!
        ...))

Note in particular that `self` can appear in any position, and that
you can freely specialize the other arguments.

(The difference from using `with-slots` is the scope of the slot
bindings: they are established *outside* of the method definition,
which means argument bindings shadow slot bindings:

    (some-method "foo" (make 'my-class :x "bar"))
    => "foo"

Since slot bindings are lexically outside the argument bindings, this
is surely correct, even if it makes `defmethods` slightly harder to
explain in terms of simpler constructs.)

Is `defmethods` trivial? Yes, in terms of its implementation. This
docstring is far longer than the code it documents. But you may find
it does a lot to keep heavily object-oriented code readable and
organized, without any loss of power.

[View source](clos.lisp#L60)

## Hooks

### `(add-hook name fn &key append)`

Add FN to the value of NAME, a hook.

[View source](hooks.lisp#L6)

### `(remove-hook name fn)`

Remove fn from the symbol value of NAME.

[View source](hooks.lisp#L14)

### `(run-hooks &rest hookvars)`

Run all the hooks in all the HOOKVARS.
The variable `*hook*` is bound to each hook as it is being run.

[View source](hooks.lisp#L22)

### `(run-hook-with-args *hook* &rest args)`

Apply each function in the symbol value of HOOK to ARGS.

[View source](hooks.lisp#L30)

### `(run-hook-with-args-until-failure *hook* &rest args)`

Like `run-hook-with-args`, but quit once a function returns nil.

[View source](hooks.lisp#L36)

### `(run-hook-with-args-until-success *hook* &rest args)`

Like `run-hook-with-args`, but quit once a function returns
non-nil.

[View source](hooks.lisp#L41)

## Fbind

### `(fbind bindings &body body)`

Binds values in the function namespace.

That is,
     (fbind ((fn (lambda () ...))))
     ≡ (flet ((fn () ...))),

except that a bare symbol in BINDINGS is rewritten as (symbol
symbol).

[View source](fbind.lisp#L206)

### `(fbind* bindings &body body)`

Like `fbind`, but creates bindings sequentially.

[View source](fbind.lisp#L243)

### `(fbindrec bindings &body body)`

Like `fbind`, but creates recursive bindings.

The consequences of referring to one binding in the expression that
generates another are undefined.

[View source](fbind.lisp#L306)

### `(fbindrec* bindings &body body)`

Like `fbindrec`, but the function defined in each binding can be
used in successive bindings.

[View source](fbind.lisp#L351)

## Lists

### `(filter-map fn list &rest lists)`

Map FN over (LIST . LISTS) like `mapcar`, but omit empty results.

     (filter-map fn ...)
     ≅ (remove nil (mapcar fn ...))

[View source](lists.lisp#L8)

### `(car-safe x)`

The car of X, or nil if X is not a cons.

This is different from Alexandria’s `ensure-car`, which returns the atom.

    (ensure-car '(1 . 2)) => 1
    (car-safe '(1 . 2)) => 1
    (ensure-car 1) => 1
    (car-safe 1) => nil

From Emacs Lisp.

[View source](lists.lisp#L34)

### `(cdr-safe x)`

The cdr of X, or nil if X is not a cons.
From Emacs Lisp.

[View source](lists.lisp#L47)

### `(append1 list item)`

Append an atom to a list.

    (append1 list item)
    ≡ (append list (list item))

[View source](lists.lisp#L52)

### `(in x &rest items)`

Is X equal to any of ITEMS?

`(in x xs...)` is always equivalent to `(member x xs :test equal)`,
but `in` can sometimes compile to more efficient code when the
candidate matches are constant.

From Arc.

[View source](lists.lisp#L59)

### `(memq item list)`

Like (member ... :test #'eq).
Should only be used for symbols.

[View source](lists.lisp#L82)

### `(delq item list)`

Like (delete ... :test #'eq), but only for lists.

Almost always used as (delq nil ...).

[View source](lists.lisp#L90)

### `(mapply fn list &rest lists)`

`mapply` is a cousin of `mapcar`.

If you think of `mapcar` as using `funcall`:

    (mapcar #'- '(1 2 3))
    ≅ (loop for item in '(1 2 3)
            collect (funcall #'- item))

Then `mapply` does the same thing, but with `apply` instead.

    (loop for item in '((1 2 3) (4 5 6))
            collect (apply #'+ item))
    => (6 15)

    (mapply #'+ '((1 2 3) (4 5 6)))
    => (6 15)

In variadic use, `mapply` acts as if `append` had first been used:

    (mapply #'+ xs ys)
    ≡ (mapply #'+ (mapcar #'append xs ys))

But the actual implementation is more efficient.

`mapply` can convert a list of two-element lists into an alist:

    (mapply #'cons '((x 1) (y 2))
    => '((x . 1) (y . 2))

[View source](lists.lisp#L107)

### `(assocdr item alist &rest args)`

Like (cdr (assoc ...))

[View source](lists.lisp#L161)

### `(assocadr item alist &rest args)`

Like `assocdr` for alists of proper lists.

     (assocdr 'x '((x 1))) => '(1)
     (assocadr 'x '((x 1))) => 1

[View source](lists.lisp#L166)

### `(rassocar item alist &rest args)`

Like (car (rassoc ...))

[View source](lists.lisp#L174)

### `(firstn n list)`

The first N elements of LIST, as a fresh list:

    (firstn 4 (iota 10))
    => (0 1 2 4)

(I do not why this extremely useful function did not make it into
Common Lisp, unless it was deliberately left out as an exercise for
Maclisp users.)

[View source](lists.lisp#L179)

### `(powerset set)`

Return the powerset of SET.
Uses a non-recursive algorithm.

[View source](lists.lisp#L191)

### `(efface item list)`

Destructively remove only the first occurence of ITEM in LIST.

From Lisp 1.5.

[View source](lists.lisp#L202)

### `(pop-assoc key alist &rest args)`

Like `assoc` but, if there was a match, delete it from ALIST.

From Newlisp.

[View source](lists.lisp#L221)

### `(mapcar-into fn list)`

Like (map-into list fn list).

From PAIP.

[View source](lists.lisp#L237)

### `(nthrest n list)`

Alias for `nthcdr`.

[View source](lists.lisp#L246)

### `(plist-keys plist)`

Return the keys of a plist.

[View source](lists.lisp#L250)

### `(plist-values plist)`

Return the values of a plist.

[View source](lists.lisp#L256)

## Strings

### `(whitespacep char)`

Is CHAR whitespace?

Spaces, tabs, any kind of line break, page breaks, and no-break spaces
are considered whitespace.

[View source](strings.lisp#L19)

### `(trim-whitespace string)`

STRING without whitespace at ends.

[View source](strings.lisp#L27)

### `(ascii-char-p char)`

Is CHAR an ASCII char?

[View source](strings.lisp#L31)

### `(with-string (var &optional stream) &body body)`

Bind VAR to the character stream designated by STREAM.

STREAM is resolved like the DESTINATION argument to `format`: it can
be any of t (for `*standard-output*`), nil (for a string stream), a
string with a fill pointer, or a stream to be used directly.

When possible, it is a good idea for functions that build strings to
take a stream to write to, so callers can avoid consing a string just
to write it to a stream. This macro makes it easy to write such
functions.

    (defun format-x (x &key stream)
      (with-string (s stream)
        ...))

[View source](strings.lisp#L50)

### `(collapse-whitespace string)`

Collapse runs of whitespace in STRING.
Each run of space, newline, and other whitespace characters is
replaced by a single space character.

[View source](strings.lisp#L79)

### `(blankp seq)`

SEQ is either empty, or consists entirely of characters that
satisfy `whitespacep`.

[View source](strings.lisp#L98)

### `(concat &rest strings)`

Abbreviation for (concatenate 'string ...).

From Emacs Lisp.

[View source](strings.lisp#L112)

### `(mapconcat fun seq separator &key stream)`

Build a string by mapping FUN over SEQ.
Separate each value with SEPARATOR.

Equivalent to
        (reduce #'concat (intersperse SEP SEQ) :key FUN)
but more efficient.

STREAM can be used to specify a stream to write to. It is resolved
like the first argument to `format`.

From Emacs Lisp.

[View source](strings.lisp#L137)

### `(string-join strings &optional separator)`

Like `(mapconcat #'string STRINGS (string SEPARATOR))'.

[View source](strings.lisp#L159)

### `(string-upcase-initials string)`

Return STRING with the first letter of each word capitalized.
This differs from STRING-CAPITALIZE in that the other characters in
each word are not changed.

     (string-capitalize "an ACRONYM") -> "An Acronym")
     (string-upcase-initials "an ACRONYM") -> "An ACRONYM")

From Emacs Lisp (where it is simply `upcase-initials`).

[View source](strings.lisp#L164)

### `(nstring-upcase-initials string)`

Destructive version of `string-upcase-initials`.

[View source](strings.lisp#L176)

### `(same-case-p string)`

Every character with case in STRING has the same case.
Return `:upper` or `:lower` as appropriate.

[View source](strings.lisp#L195)

### `(nstring-invert-case string)`

Destructive version of `string-invert-case`.

[View source](strings.lisp#L218)

### `(string-invert-case string)`

Invert the case of STRING.
This does the same thing as a case-inverting readtable.

[View source](strings.lisp#L227)

### `(words string &key start end)`

Split STRING into words.

The definition of a word is the same as that used by
`string-capitalize`: a run of alphanumeric characters.

    (words "Four score and seven years")
    => ("Four" "score" "and" "seven" "years")

    (words "2 words")
    => ("2" "words")

    (words "two_words")
    => ("two" "words")

    (words "\"I'm here,\" Tom said presently.")
    => ("I" "m" "here" "Tom" "said" "presently")

Cf. `tokens`.

[View source](strings.lisp#L234)

### `(tokens string &key start end)`

Separate STRING into tokens.
Tokens are runs of non-whitespace characters.

    (tokens "\"I'm here,\" Tom said presently.")
    => ("\"I'm" "here,\"" "Tom" "said" "presently.")

Cf. `words`.

[View source](strings.lisp#L264)

### `(word-wrap string &key column stream)`

Return a word-wrapped version of STRING that breaks at COLUMN.

Note that this is not a general-purpose word-wrapping routine like you
would find in a text editor: in particular, any existing whitespace is
removed.

[View source](strings.lisp#L279)

### `(lines string)`

A list of lines in STRING.

[View source](strings.lisp#L311)

### `(fmt control-string &rest args)`

A cousin of `format` expressly for fast formatting of strings.

Like (format nil ...), binding `*pretty-pretty*` to `nil`, which in
some Lisps means a significant increase in speed.

Has a compiler macro with `formatter`.

[View source](strings.lisp#L316)

### `(escape string table &key start end stream)`

Write STRING to STREAM, escaping with TABLE.

TABLE should be either a hash table, with characters for keys and
strings for values, or a function that takes a character and returns a
string.

STREAM can be used to specify a stream to write to, like the first
argument to `format`. The default behavior, with no stream specified,
is to return a string.

[View source](strings.lisp#L331)

### `(ellipsize string n &key ellipsis)`

If STRING is longer than N, truncate it and append ELLIPSIS.

Note that the resulting string is longer than N by the length of
ELLIPSIS, so the string may come out longer than it started.

     (ellipsize "abc" 2)
     => "ab..."

From Arc.

[View source](strings.lisp#L363)

### `(string-prefixp s1 s2 &key start1 end1 start2 end2)`

Like `string^=`, but case-insensitive.

[View source](strings.lisp#L402)

### `(string^= s1 s2 &key start1 end1 start2 end2)`

Is S1 a prefix of S2?

[View source](strings.lisp#L402)

### `(string-suffixp s1 s2 &key start1 end1 start2 end2)`

Like `string$=`, but case-insensitive.

[View source](strings.lisp#L407)

### `(string$= s1 s2 &key start1 end1 start2 end2)`

Is S1 a suffix of S2?

[View source](strings.lisp#L407)

### `(string-containsp s1 s2 &key start1 end1 start2 end2)`

Like `string*=`, but case-insensitive.

[View source](strings.lisp#L412)

### `(string*= s1 s2 &key start1 end1 start2 end2)`

Is S1 a substring of S2?

This is similar, but not identical, to SEARCH.

     (search nil "foo") => 0
     (search "nil" "nil") => 0
     (string*= nil "foo") => NIL
     (string*= nil "nil") => T

[View source](strings.lisp#L412)

### `(string~= s1 s2 &key start1 end1 start2 end2)`

Does S1 occur in S2 as a token?

Equivalent to
     (find S1 (tokens S2) :test #'string=),
but without consing.

[View source](strings.lisp#L423)

### `(string-tokenp s1 s2 &key start1 end1 start2 end2)`

Like `string~=`, but case-insensitive.

[View source](strings.lisp#L423)

### `(string-replace old string new &key start end stream)`

Like `string-replace-all`, but only replace the first match.

[View source](strings.lisp#L447)

### `(string-replace-all old string new &key start end stream)`

Do search-and-replace for constant strings.

Note that START and END only affect where the replacements are made:
the part of the string before START, and the part after END, are
always included verbatim.

     (string-replace-all "old" "The old old way" "new"
                         :start 3 :end 6)
     => "The new old way"

STREAM can be used to specify a stream to write to. It is resolved
like the first argument to `format`.

[View source](strings.lisp#L463)

### `(chomp string &optional suffixes)`

If STRING ends in one of SUFFIXES, remove that suffix.

SUFFIXES defaults to a Lisp newline, a literal line feed, a literal
carriage return, or a literal carriage return followed by a literal
line feed.

Takes care that the longest suffix is always removed first.

[View source](strings.lisp#L502)

## Sequences

### `(nsubseq seq start &optional end)`

Return a subsequence that may share structure with SEQ.

Note that `nsubseq` gets its aposematic leading `n` not because it is
itself destructive, but because, unlike `subseq`, destructive
operations on the subsequence returned may mutate the original.

`nsubseq` also works with `setf`, with the same behavior as
`replace`.

[View source](sequences.lisp#L153)

### `(filter pred seq &rest args &key count &allow-other-keys)`

Almost, but not quite, an alias for `remove-if-not`.

The difference is the handling of COUNT: for `filter`, COUNT is the
number of items to *keep*, not remove.

     (remove-if-not #'oddp '(1 2 3 4 5) :count 2)
     => '(1 3 5)

     (filter #'oddp '(1 2 3 4 5) :count 2)
     => '(1 3)

[View source](sequences.lisp#L207)

### `(filterf g pred &rest args)`

Modify-macro for FILTER.
The place designed by the first argument is set to th result of
calling FILTER with PRED, the place, and ARGS.

[View source](sequences.lisp#L236)

### `(keep item seq &rest args &key test from-end key count &allow-other-keys)`

Almost, but not quite, an alias for `remove` with `:test-not` instead of `:test`.

The difference is the handling of COUNT. For keep, COUNT is the number of items to keep, not remove.

     (remove 'x '(x y x y x y) :count 2)
     => '(y y x y)

     (keep 'x '(x y x y x y) :count 2)
     => '(x x)

`keep` becomes useful with the KEY argument:

     (keep 'x ((x 1) (y 2) (x 3)) :key #'car)
     => '((x 1) (x 3))

[View source](sequences.lisp#L242)

### `(single seq)`

Is SEQ a sequence of one element?

[View source](sequences.lisp#L276)

### `(partition pred seq &key start end key)`

Partition elements of SEQ into those for which PRED returns true
and false.

Return two values, one with each sequence.

Exactly equivalent to:
     (values (remove-if-not predicate seq) (remove-if predicate seq))
except it visits each element only once.

Note that `partition` is not just `assort` with an up-or-down
predicate. `assort` returns its groupings in the order they occur in
the sequence; `partition` always returns the “true” elements first.

    (assort '(1 2 3) :key #'evenp) => ((1 3) (2))
    (partition #'evenp '(1 2 3)) => (2), (1 3)

[View source](sequences.lisp#L282)

### `(partitions preds seq &key start end key)`

Generalized version of PARTITION.

PREDS is a list of predicates. For each predicate, `partitions`
returns a filtered copy of SEQ. As a second value, it returns an extra
sequence of the items that do not match any predicate.

Items are assigned to the first predicate they match.

[View source](sequences.lisp#L307)

### `(assort seq &key key test start end)`

Return SEQ assorted by KEY.

     (assort (iota 10)
             :key (lambda (n) (mod n 3)))
     => '((0 3 6 9) (1 4 7) (2 5 8))

You can think of `assort` as being akin to `remove-duplicates`:

     (mapcar #'first (assort list))
     ≡ (remove-duplicates list :from-end t)

[View source](sequences.lisp#L330)

### `(runs seq &key start end key test)`

Return a list of runs of similar elements in SEQ.
The arguments START, END, and KEY are as for `reduce`.

    (runs '(head tail head head tail))
    => '((head) (tail) (head head) (tail))

[View source](sequences.lisp#L377)

### `(batches seq n &key start end)`

Return SEQ in batches of N elements.

    (batches (iota 11) 2)
    => ((0 1) (2 3) (4 5) (6 7) (8 9) (10))

[View source](sequences.lisp#L402)

### `(frequencies seq &rest hash-table-args &key key &allow-other-keys)`

Return a hash table with the count of each unique item in SEQ.
As a second value, return the length of SEQ.

From Clojure.

[View source](sequences.lisp#L431)

### `(scan fn seq &key key initial-value)`

A version of `reduce` that shows its work.

Instead of returning just the final result, `scan` returns a sequence
of the successive results at each step.

    (reduce #'+ '(1 2 3 4))
    => 10

    (scan #'+ '(1 2 3 4))
    => '(1 3 6 10)

From APL and descendants.

[View source](sequences.lisp#L453)

### `(nub seq &rest args &key start end key test)`

Remove duplicates from SEQ, starting from the end.
TEST defaults to `equal`.

From Haskell.

[View source](sequences.lisp#L477)

### `(gcp seqs &key test)`

The greatest common prefix of SEQS.

If there is no common prefix, return NIL.

[View source](sequences.lisp#L485)

### `(gcs seqs &key test)`

The greatest common suffix of SEQS.

If there is no common suffix, return NIL.

[View source](sequences.lisp#L502)

### `(length< &rest seqs)`

Is each length-designator in SEQS shorter than the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L520)

### `(length> &rest seqs)`

Is each length-designator in SEQS longer than the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L526)

### `(length>= &rest seqs)`

Is each length-designator in SEQS longer or as long as the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L553)

### `(length<= &rest seqs)`

Is each length-designator in SEQS as long or shorter than the next?
A length designator may be a sequence or an integer.

[View source](sequences.lisp#L558)

### `(longer x y)`

Return the longer of X and Y.

If X and Y are of equal length, return X.

[View source](sequences.lisp#L563)

### `(longest seqs)`

Return the longest seq in SEQS.

[View source](sequences.lisp#L587)

### `(slice seq start &optional end)`

Like `subseq`, but allows negative bounds to specify offsets.
Both START and END accept negative bounds.

     (slice "string" -3 -1) => "in"

Setf of `slice` is like setf of `ldb`: afterwards, the place being set
holds a new sequence which is not EQ to the old.

[View source](sequences.lisp#L609)

### `(ordering seq &key unordered-to-end from-end test key)`

Given a sequence, return a function that, when called with `sort`,
restores the original order of the sequence.

That is, for any SEQ (without duplicates), it is always true that

     (equal seq (sort (shuffle (copy-seq seq)) (ordering seq)))

FROM-END controls what to do in case of duplicates. If FROM-END is
true, the last occurrence of each item is preserved; otherwise, only
the first occurrence counts.

TEST controls identity; it should be a valid test for a hash table. If
the items cannot be compared that way, you can use KEY to transform
them.

UNORDERED-TO-END controls where to sort items that are not present in
the original ordering. By default they are sorted first but, if
UNORDERED-TO-END is true, they are sorted last. In either case, they
are left in no particular order.

[View source](sequences.lisp#L643)

### `(take n seq)`

Return, at most, the first N elements of SEQ, as a *new* sequence
of the same type as SEQ.

If N is longer than SEQ, SEQ is simply copied.

[View source](sequences.lisp#L686)

### `(drop n seq)`

Return all but the first N elements of SEQ.
The sequence returned is a new sequence of the same type as SEQ.

If N is greater than the length of SEQ, returns an empty sequence of
the same type.

[View source](sequences.lisp#L696)

### `(bestn n seq pred &key key memo)`

Partial sorting.
Equivalent to (firstn N (sort SEQ PRED)), but much faster, at least
for small values of N.

With MEMO, use a decorate-sort-undecorate transform to ensure KEY is
only ever called once per element.

The name is from Arc.

[View source](sequences.lisp#L808)

### `(extrema seq pred &key key start end)`

Like EXTREMUM, but returns both the minimum and the maximum (as two
values).

     (extremum (iota 10) #'>) => 9
     (extrema (iota 10) #'>) => 9, 0

[View source](sequences.lisp#L856)

### `(halves seq &optional split)`

Return, as two values, the first and second halves of SEQ.
SPLIT designates where to split SEQ; it defaults to half the length,
but can be specified.

The split is made using `ceiling` rather than `truncate`. This is on
the theory that, if SEQ is a single-element list, it should be
returned unchanged.

[View source](sequences.lisp#L892)

### `(dsu-sort seq fn &key key stable)`

Decorate-sort-undecorate using KEY.
Useful when KEY is an expensive function (e.g. database access).

[View source](sequences.lisp#L910)

### `(deltas seq &optional fn)`

Return the successive differences in SEQ.

     (deltas '(4 9 -5 1 2))
     => '(4 5 -14 6 1)

Note that the first element of SEQ is also the first element of the
return value.

By default, the delta is the difference, but you can specify another
function as a second argument:

    (deltas '(2 4 2 6) #'/)
    => '(2 2 1/2 3)

From Q.

[View source](sequences.lisp#L925)

### `(inconsistent-graph-constraints x)`

The constraints of an `inconsistent-graph` error.
Cf. `toposort`.

[View source](sequences.lisp#L949)

### `(toposort constraints &key test tie-breaker from-end unordered-to-end)`

Turn CONSTRAINTS into a predicate for use with SORT.

Each constraint should be two-element list.

    (def dem-bones '((toe foot)
                     (foot heel)
                     (heel ankle)
                     (ankle shin)
                     (shin knee)
                     (knee back)
                     (back shoulder)
                     (shoulder neck)
                     (neck head)))
    (sort (shuffle (mapcar #'car dem-bones))
          (toposort dem-bones))
    => (TOE FOOT HEEL ANKLE SHIN KNEE BACK SHOULDER NECK)

If the graph is inconsistent, signals an error of type
`inconsistent-graph`:

    (toposort '((chicken egg) (egg chicken)))
    => Inconsistent graph: ((CHICKEN EGG) (EGG CHICKEN))

TEST, FROM-END, and UNORDERED-TO-END are passed through to
`ordering`.

[View source](sequences.lisp#L986)

### `(intersperse new-elt seq)`

Return a sequence like SEQ, but with NEW-ELT inserted between each
element.

[View source](sequences.lisp#L1044)

### `(mvfold fn seq &rest seeds)`

Like `reduce` extended to multiple values.

Calling `mvfold` with one seed is equivalent to `reduce`:

    (mvfold fn xs seed) ≡ (reduce fn xs :initial-value seed)

However, you can also call `mvfold` with multiple seeds:

    (mvfold fn xs seed1 seed2 seed3 ...)

How is this useful? Consider extracting the minimum of a sequence:

    (reduce #'min xs)

Or the maximum:

    (reduce #'max xs)

But both?

    (reduce (lambda (cons item)
              (cons (min (car cons) item)
                    (max (cdr cons) item)))
            xs
            :initial-value (cons (elt xs 0) (elt xs 0)))

You can do this naturally with `mvfold`.

    (mvfold (lambda (min max item)
              (values (min item min)
                      (max item max)))
            xs (elt xs 0) (elt xs 0))

In general `mvfold` provides a functional idiom for “loops with
book-keeping” where we might otherwise have to use recursion or
explicit iteration.

Has a compiler macro that generates efficient code when the number of
SEEDS is fixed at compile time (as it usually is).

[View source](sequences.lisp#L1073)

### `(mvfoldr fn seq &rest seeds)`

Like `(reduce FN SEQ :from-end t)' extended to multiple
values. Cf. `mvfold`.

[View source](sequences.lisp#L1115)

