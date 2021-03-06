(in-package :serapeum)
(in-readtable :fare-quasiquote)

(defmacro eval-always (&body body)
  "Shorthand for
        (eval-when (:compile-toplevel :load-toplevel :execute) ...)"
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     ,@body))

(defmacro eval-and-compile (&body body)
  "Emacs's `eval-and-compile'.
Alias for `eval-always'."
  `(eval-always
     ,@body))

(defun no (x)
  "Another alias for `not' and `null'.

From Arc."
  (not x))

(define-compiler-macro no (x)
  `(not ,x))

(defmacro nor (&rest forms)
  "Equivalent to (not (or ...)).

From Arc."
  (if (null forms) t
      (if (null (rest forms))
          `(not ,(first forms))
          `(if ,(first forms)
               nil
               (nor ,@(rest forms))))))

(defmacro nand (&rest forms)
  "Equivalent to (not (and ...))."
  (if (null forms) nil
      (if (null (rest forms))
          `(not ,(first forms))
          `(if ,(first forms)
               (nand ,@(rest forms))
               t))))

(defun same-type? (type1 type2 &optional env)
  "Like `alexandria:type=', but takes an environment."
  (multiple-value-bind (sub sure) (subtypep type1 type2 env)
    (if (not sub)
        (values nil sure)
        (subtypep type2 type1 env))))

(defun describe-non-exhaustive-match (stream partition type env)
  (assert (not (same-type? partition type)))
  (labels ((explode-type (type)
             (match type
               ((list* 'or subtypes) subtypes)
               ((list* 'member subtypes)
                (loop for subtype in subtypes collect `(eql ,subtype)))))

           (extra-types (partition)
             (loop for subtype in (explode-type partition)
                   unless (subtypep subtype type env)
                     collect subtype))

           (format-extra-types (stream partition)
             (when-let (et (extra-types partition))
               (format stream "~&There are extra types: ~s" et)))

           (missing-types (partition)
             (multiple-value-bind (exp exp?) (typexpand type env)
               (when exp?
                 (set-difference (explode-type exp)
                                 (explode-type partition)
                                 :test #'type=))))

           (format-missing-types (stream partition)
             (when-let (mt (missing-types partition))
               (format stream "~&There are missing types: ~s" mt)))

           (format-subtype-problem (stream partition)
             (cond ((subtypep partition type env)
                    (format stream "~s is a proper subtype of ~s." partition type))
                   ((subtypep type partition env)
                    (format stream "~s contains types not in ~s." partition type))
                   (t (format stream "~s is not the same as ~s" partition type)))))

    (format stream "~&Non-exhaustive match: ")
    (format-subtype-problem stream partition)
    (format-extra-types stream partition)
    (format-missing-types stream partition)))

(defun check-exhaustiveness (style type clauses env)
  ;; Should we do redundancy checking? Is there any Lisp that doesn't
  ;; already warn about that?
  (check-type style (member case typecase))
  (multiple-value-bind (clause-types partition)
      (ecase style
        ((typecase)
         (loop for (type . nil) in clauses
               collect type into clause-types
               finally (return (values clause-types
                                       `(or ,@clause-types)))))
        ((case)
         (loop for (key-spec . nil) in clauses
               for keys = (ensure-list key-spec)
               for clause-type = `(member ,@keys)
               collect clause-type into clause-types
               append keys into all-keys
               finally (return (values clause-types
                                       `(member ,@all-keys))))))
    ;; Check that every clause type is a subtype of TYPE.
    (dolist (clause-type clause-types)
      (multiple-value-bind (subtype? sure?)
          (subtypep clause-type type env)
        (cond ((not sure?)
               (warn "Can't tell if ~s is a subtype of ~s. Is ~s defined?"
                     clause-type type type))
              ((not subtype?)
               (warn "~s is not a subtype of ~s" clause-type type)))))
    ;; Check that the clause types form an exhaustive partition of TYPE.
    (multiple-value-bind (same sure)
        (same-type? partition type env)
      (cond ((not sure)
             (warn "Can't check exhaustiveness: cannot determine if ~s is the same as ~s"
                   partition type))
            (same)
            (t (warn "~a"
                     (with-output-to-string (s)
                       (describe-non-exhaustive-match s partition type env)))))))
  (values))

(defmacro typecase-of (type x &body clauses &environment env)
  "Like `etypecase-of', but may, and must, have an `otherwise' clause
in case X is not of TYPE."
  (let* ((otherwise (find 'otherwise clauses :key #'car))
         (clauses (remove otherwise clauses)))
    (unless otherwise
      (error "No otherwise clause in typecase-of for type ~s" type))

    (check-exhaustiveness 'typecase type clauses env)
    `(typecase ,x
       ,@clauses
       ,otherwise)))

(defmacro etypecase-of (type x &body body)
  "Like `etypecase' but, at compile time, warn unless each clause in
BODY is a subtype of TYPE, and the clauses in BODY form an exhaustive
partition of TYPE."
  (once-only (x)
    `(typecase-of ,type ,x
       ,@body
       (otherwise
        (error 'type-error
               :datum ,x
               :expected-type ',type)))))

(defmacro case-of (type x &body clauses &environment env)
  "Like `case' but may, and must, have an `otherwise' clause "
  (let* ((otherwise (find 'otherwise clauses :key #'car))
         (clauses (remove otherwise clauses)))
    (unless otherwise
      (error "No otherwise clause in case-of for type ~s" type))

    (check-exhaustiveness 'case type clauses env)
    `(case ,x
       ,@clauses
       ,otherwise)))

(defmacro ecase-of (type x &body body)
  "Like `ecase' but, given a TYPE (which should be defined as `(member
...)'), warn, at compile time, unless the keys in BODY are all of TYPE
and, taken together, they form an exhaustive partition of TYPE."
  (once-only (x)
    `(case-of ,type ,x
       ,@body
       (otherwise
        (error 'type-error
               :datum ,x
               :expected-type ',type)))))

(defmacro ctypecase-of (type keyplace &body body &environment env)
  "Like `etypecase-of', but providing a `store-value' restart to correct KEYPLACE and try again."
  (check-exhaustiveness 'typecase type body env)
  `(ctypecase ,keyplace ,@body))

(defmacro ccase-of (type keyplace &body body &environment env)
  "Like `ecase-of', but providing a `store-value' restart to correct KEYPLACE and try again."
  (check-exhaustiveness 'case type body env)
  `(ccase ,keyplace ,@body))

;;; Adapted from Alexandria.
(defun expand-destructuring-case-of (type key clauses case-of)
  (once-only (key)
    `(if (typep ,key 'cons)
         (,case-of ,type (car ,key)
           ,@(mapcar (lambda (clause)
                       (destructuring-bind ((keys . lambda-list) &body body) clause
                         `(,keys
                           (destructuring-bind ,lambda-list (cdr ,key)
                             ,@body))))
                     clauses))
         (error "Invalid key to DESTRUCTURING-~S: ~S" ',case-of ,key))))

(defmacro destructuring-ecase-of (type expr &body body)
  "Like `destructuring-ecase', from Alexandria, but with exhaustivness
checking.

TYPE is a designator for a type, which should be defined as `(member
...)'. At compile time, the macro checks that, taken together, the
symbol at the head of each of the destructuring lists in BODY form an
exhaustive partition of TYPE, and warns if it is not so."
  (expand-destructuring-case-of type expr body 'ecase-of))

(defmacro destructuring-case-of (type expr &body body)
  "Like `destructuring-ecase-of', but an `otherwise' clause must also be supplied.

Note that the otherwise clauses must also be a list:

    ((otherwise &rest args) ...)"
  (expand-destructuring-case-of type expr body 'case-of))

(defmacro destructuring-ccase-of (type keyplace &body body)
  "Like `destructuring-case-of', but providing a `store-value' restart
to collect KEYPLACE and try again."
  (expand-destructuring-case-of type keyplace body 'ccase-of))

(defmacro case-using (pred keyform &body clauses)
  "ISLISP's case-using.

     (case-using #'eql x ...)
     ≡ (case x ...).

Note that, no matter the predicate, the keys are not evaluated. (But see `selector'.)

This version supports both single-item clauses (x ...) and
multiple-item clauses ((x y) ...), as well as (t ...) or (otherwise
...) for the default clause."
  (case (extract-function-name pred)
    (eql `(case ,keyform ,@clauses))
    (string= `(string-case ,keyform ,@clauses))
    (t (once-only (keyform)
         (rebinding-functions (pred)
           `(case-using-aux ,pred ,keyform ,@clauses))))))

(defmacro case-using-aux (pred keyform &body clauses)
  (if (not clauses)
      nil
      (destructuring-bind ((key . body) . clauses) clauses
        (if (member key '(t otherwise))
            `(progn ,@body)
            `(if (or ,@(mapcar (lambda (key)
                                 `(funcall ,pred ,keyform ',key))
                               (ensure-list key)))
                 (progn ,@body)
                 (case-using-aux ,pred ,keyform
                   ,@clauses))))))

(defun expand-string-case (sf default cases)
  "Expand a string-case macro with a minimum of duplicated code."
  (once-only (sf)
    (let* ((key-lists (mapcar #'car cases))
           (keys (apply #'append key-lists)))
      (flet ((single (l)
               (if (listp l)
                   (null (cdr l))
                   (= (length l) 1))))
        (cond
          ;; Every string is of length 1.
          ((every #'single keys)
           `(and (= (length ,sf) 1)
                 (case (aref ,sf 0)
                   ,@(loop for (key-list . body) in cases
                           collect `(,(mapcar (lambda (key)
                                                (aref key 0))
                                              key-list)
                                     ,@body)))))
          ((every #'single key-lists)
           ;; Each clause has only one key.
           `(string-case:string-case (,sf :default ,default)
              ,@(loop for ((k) . body) in cases
                      collect (cons k body))))
          ;; Some clauses have multiple keys.
          (t
           (let* ((simple (remove-if-not #'single cases :key #'car))
                  (complex (set-difference cases simple)))
             (with-gensyms (block)
               `(block ,block
                  ,(let ((tags (make-gensym-list (length complex) (string 'body))))
                     `(tagbody
                         (return-from ,block
                           (string-case:string-case (,sf :default ,default)
                             ;; Just inline the simple clauses.
                             ,@(loop for ((key) . body) in simple
                                     collect `(,key ,@body))
                             ;; Convert the complex clauses into a
                             ;; series of simple clauses that jump to
                             ;; the same body.
                             ,@(loop for key-lists in (mapcar #'car complex)
                                     for tag in tags
                                     append (loop for k in key-lists
                                                  collect `(,k (go ,tag))))))
                         ;; The tags to jump to.
                         ,@(loop for tag in tags
                                 for body in (mapcar #'cdr complex)
                                 append `(,tag (return-from ,block (progn ,@body)))))))))))))))

(defmacro string-case (stringform &body cases)
  "Efficient `case'-like macro with string keys.

This uses Paul Khuong's `string-case' macro internally."
  (multiple-value-bind (cases default)
      (normalize-cases cases)
    (expand-string-case stringform `(progn ,@default) cases)))

(defmacro string-ecase (stringform &body cases)
  "Efficient `ecase'-like macro with string keys.

Cf. `string-case'."
  (let* ((cases (normalize-cases cases :allow-default nil))
         (keys (mappend (compose #'ensure-list #'car) cases)))
    (once-only (stringform)
      (expand-string-case stringform
                          `(error "~s is not one of ~s"
                                  ,stringform ',keys)
                          cases))))

(defmacro eif (test then else)
  "Like `cl:if', but requires two branches.
Stands for “exhaustive if”."
  `(if ,test ,then ,else))

(defmacro eif-let (binds then else)
  "Like `alexandria:if-let', but requires two branches."
  `(if-let ,binds ,then ,else))

(defun format-econd-tests (stream tests)
  (format stream "~@[~&None of these tests were satisfied: ~
                    ~{~%~^~a~}~]"
          tests))

(define-condition econd-failure (error)
  ((tests :type list :initarg :tests))
  (:default-initargs :tests nil)
  (:report (lambda (c s)
             (with-slots (tests) c
               (format s "ECOND fell through.")
               (format-econd-tests s tests))))
  (:documentation "A failed ECOND form."))

(defmacro econd (&rest clauses)
  "Like `cond', but signal an error of type `econd-failure' if no
clause succeeds."
  (let ((tests (mapcar #'car clauses)))
    `(cond ,@clauses
           ;; SBCL will silently eliminate this branch if it is
           ;; unreachable.
           (t (error 'econd-failure :tests ',tests)))))

(defmacro cond-let (var &body clauses)
  "Cross between COND and LET.

     (cond-let x ((test ...)))
     ≡ (let (x)
         (cond ((setf x test) ...)))

Cf. `acond' in Anaphora."
  (match clauses
    (() nil)
    (`((,test) ,@clauses)
      `(if-let (,var ,test)
         ,var
         (cond-let ,var ,@clauses)))
    (`((t ,@body) ,@_)
      `(progn ,@body))
    (`((,test ,@body) ,@clauses)
      `(if-let (,var ,test)
         (progn ,@body)
         (cond-let ,var ,@clauses)))))

(defmacro econd-let (symbol &rest clauses)
  "Like `cond-let' for `econd'."
  `(cond-let ,symbol
     ,@clauses
     (t (error 'econd-failure))))

;;; cond-every has the same syntax as cond, but executes every clause
;;; whose condition is satisfied, not just the first. If a condition
;;; is the symbol otherwise, it is satisfied if and only if no
;;; preceding condition is satisfied. The value returned is the value
;;; of the last body form in the last clause whose condition is
;;; satisfied. Multiple values are not returned.

(defmacro cond-every (&body clauses)
  "Like `cond', but instead of stopping after the first clause that
succeeds, run all the clauses that succeed.

Return the value of the last successful clause.

If a clause begins with `cl:otherwise', it runs only if no preceding
form has succeeded.

Note that this does *not* do the same thing as a series of `when'
forms: `cond-every' evaluates *all* the tests *before* it evaluates
any of the forms.

From Zetalisp."
  (let* ((otherwise-clause (find 'otherwise clauses :key #'car))
         (test-clauses (remove otherwise-clause clauses))
         (temps (make-gensym-list (length test-clauses))))
    `(let* ,(loop for temp in temps
                  for (test . nil) in test-clauses
                  collect `(,temp ,test))
       (if (not (or ,@temps))
           (progn ,@(rest otherwise-clause))
           ,(with-gensyms (ret)
              `(let (,ret)
                 ,@(loop for temp in temps
                         for (nil . body) in test-clauses
                         collect `(when ,temp
                                    (setf ,ret
                                          ,(if (null body)
                                               temp
                                               `(progn ,@body)))))
                 ,ret))))))

(defmacro bcond (&rest clauses)
  "Scheme's extended COND.

This is exactly like COND, except for clauses having the form

     (test :=> recipient)

In that case, if TEST evaluates to a non-nil result, then RECIPIENT, a
function, is called with that result, and the result of RECIPIENT is
return as the value of the `cond`.

As an extension, a clause like this:

     (test :=> var ...)

Can be used as a shorthand for

     (test :=> (lambda (var) ...))

The name `bcond' for a “binding cond” goes back at least to the days
of the Lisp Machines. I do not know who was first to use it, but the
oldest examples I have found are by Michael Parker and Scott L.
Burson."
  (flet ((send-clause? (clause)
           (let ((second (second clause)))
             (and (symbolp second)
                  (string= second :=>))))
         (parse-send-clause (clause)
           (destructuring-bind (test => . body) clause
             (declare (ignore =>))
             (cond ((null body) (error "Missing clause"))
                   ((null (rest body))
                    (values test (car body)))
                   (t (destructuring-bind (var . body) body
                        (let ((fn `(lambda (,var) ,@body)))
                          (values test fn))))))))
    ;; Note that we expand into `cond' rather than `if' so we don't
    ;; have to handle tests without bodies.
    (cond ((null clauses) nil)
          ((member-if #'send-clause? clauses)
           (let* ((tail (member-if #'send-clause? clauses))
                  (preceding (ldiff clauses tail))
                  (clause (car tail))
                  (clauses (cdr tail)))
             (multiple-value-bind (test fn)
                 (parse-send-clause clause)
               (with-gensyms (tmp)
                 `(cond ,@preceding
                        (t (if-let (,tmp ,test)
                             (funcall ,fn ,tmp)
                             (bcond ,@clauses))))))))
          (t `(cond ,@clauses)))))

(defmacro case-let ((var expr) &body cases)
  "Like (let ((VAR EXPR)) (case VAR ...))"
  `(let ((,var ,expr))
     (case ,var
       ,@cases)))

(defmacro ecase-let ((var expr) &body cases)
  "Like (let ((VAR EXPR)) (ecase VAR ...))"
  `(let ((,var ,expr))
     (case ,var
       ,@cases)))

(defmacro comment (&body body)
  "A macro that ignores its body and does nothing. Useful for
comments-by-example.

Also, as noted in EXTENSIONS.LISP of 1992, \"This may seem like a
silly macro, but used inside of other macros or code generation
facilities it is very useful - you can see comments in the (one-time)
macro expansion!\""
  (declare (ignore body)))

(defmacro example (&body body)
  "Like `comment'."
  `(comment ,@body))

(defmacro nix (place &environment env)
  "Set PLACE to nil and return the old value of PLACE.

This may be more efficient than (shiftf place nil), because it only
sets PLACE when it is not already null."
  (multiple-value-bind (vars vals new setter getter)
      (get-setf-expansion place env)
    `(let* (,@(mapcar #'list vars vals)
            (,(car new) ,getter))
       (and ,(car new)
            (prog1 ,(car new)
              (setq ,(car new) nil)
              ,setter)))))

;;; https://groups.google.com/d/msg/comp.lang.lisp/cyWz2Vyd70M/wYPKr24OEYMJ
(defmacro ensure (place &body newval
                        &environment env)
  "Essentially (or place (setf place newval)).

PLACE is treated as unbound if it returns `nil', signals
`unbound-slot', or signals `unbound-variable'.

Note that ENSURE is `setf'-able, so you can do things like
     (incf (ensure x 0))

Cf. `ensure2'."
  (multiple-value-bind (vars vals stores setter getter)
      (get-setf-expansion place env)
    `(let* ,(mapcar #'list vars vals)
       (or (ignoring (or unbound-slot unbound-variable)
             ,getter)
           (multiple-value-bind ,stores
               (progn ,@newval)
             (when ,(first stores)
               ,setter))))))

(define-setf-expander ensure (place &body newval &environment env)
  (multiple-value-bind (vars vals stores setter getter)
      (get-setf-expansion place env)
    (values vars
            vals
            stores
            setter
            `(or (ignoring (or unbound-slot unbound-variable)
                   ,getter)
                 (progn ,@newval)))))

(defmacro ensure2 (place &body newval &environment env)
  "Like `ensure', but specifically for accessors that return a second
value like `gethash'."
  (multiple-value-bind (vars vals stores setter getter)
      (get-setf-expansion place env)
    (with-gensyms (old presentp)
      `(let* ,(mapcar #'list vars vals)
         (multiple-value-bind (,old ,presentp)
             ,getter
           (if ,presentp
               ,old
               (multiple-value-bind ,stores
                   (progn ,@newval)
                 ,setter)))))))

(define-setf-expander ensure2 (place &body newval &environment env)
  (multiple-value-bind (vars vals stores setter getter)
      (get-setf-expansion place env)
    (values vars
            vals
            stores
            setter
            (with-gensyms (old presentp)
              `(multiple-value-bind (,old ,presentp)
                   ,getter
                 (if ,presentp
                     ,old
                     ,newval))))))

(defun thread-aux (threader needle holes thread-fn)
  ;; http://christophe.rhodes.io/notes/blog/posts/2014/code_walking_for_pipe_sequencing/
  (flet ((str= (x y)
           (and (symbolp x) (symbolp y) (string= x y))))
    #+sbcl
    (labels ((find-_ (form env)
               (sb-walker:walk-form form env
                                    (lambda (f c e) (declare (ignore c e))
                                      (cond
                                        ((str= f '_) (return-from find-_ f))
                                        ((eql f form) f)
                                        (t (values f t)))))
               nil)
             (walker (form c env) (declare (ignore c))
               (cond
                 ((symbolp form) (list form))
                 ((atom form) form)
                 (t (if-let (_ (find-_ form env))
                      (values `(let ((,_ ,needle))
                                 ,form)
                              t)
                      (values (funcall thread-fn needle form) t))))))
      (if (not holes)
          needle
          `(,threader ,(sb-walker:walk-form (first holes) nil #'walker)
                      ,@(rest holes))))
    #-sbcl
    (if (not holes)
        needle
        `(,threader ,(let ((hole (first holes)))
                       (if (listp hole)
                           (if-let (_ (find '_ hole :test #'str=))
                             `(let ((,_ ,needle))
                                ,hole)
                             (funcall thread-fn needle hole))
                           `(,hole ,needle)))
                    ,@(rest holes)))))

(defmacro ~> (needle &rest holes)
  "Threading macro from Clojure (by way of Racket).

Thread NEEDLE through HOLES, where each hole is either a
symbol (equivalent to `(hole needle)`) or a list (equivalent to `(hole
needle args...)`).

As an extension, an underscore in the argument list is replaced with
the needle, so you can pass the needle as an argument other than the
first."
  (thread-aux '~> needle holes
              (lambda (needle hole)
                (list* (car hole) needle (cdr hole)))))

(defmacro ~>> (needle &rest holes)
  "Like `~>' but, by default, thread NEEDLE as the last argument
instead of the first."
  (thread-aux '~>> needle holes
              (lambda (needle hole)
                (append1 hole needle))))

(defmacro nest (&rest things)
  "Like ~>>, but backward.

This is useful when layering `with-x' macros where the order is not
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

If the outer macro has no arguments, you may omit the parentheses.

    (nest
      with-standard-io-syntax
      ...)
    ≡ (with-standard-io-syntax
        ...)

From UIOP, based on a suggestion by Marco Baringer."
  (reduce (lambda (outer inner)
            (let ((outer (ensure-list outer)))
              `(,@outer ,inner)))
          things
          :from-end t))

(defmacro select (keyform &body clauses)
  "Like `case', but with evaluated keys.

Note that, like `case', `select' interprets a list as the first
element of a clause as a list of keys. To use a form as a key, you
must add an extra set of parentheses.

     (select 2
       ((+ 2 2) t))
     => T

     (select 4
       (((+ 2 2)) t))
     => T

From Zetalisp."
  `(selector ,keyform eql
     ,@clauses))

(defmacro selector (keyform fn &body clauses)
  "Like `select', but compare using FN.

Note that (unlike `case-using'), FN is not evaluated.

From Zetalisp."
  `(select-aux ,keyform cond ,fn ,@clauses))

(defmacro select-aux (keyform cond fn &body clauses)
  (once-only (keyform)
    `(,cond
       ,@(loop for (test . body) in clauses
               collect (if (atom test)
                           `((,fn ,keyform ,test) ,@body)
                           `((or ,@(mapcar (lambda (x) `(,fn ,keyform ,x)) test))
                             ,@body))))))

(def sorting-networks
  '((2
     (0 1))
    (3
     (1 2)
     (0 2)
     (0 1))
    (4
     (0 1)
     (2 3)
     (0 2)
     (1 3)
     (1 2))
    (5
     (0 1)
     (3 4)
     (2 4)
     (2 3)
     (0 3)
     (0 2)
     (1 4)
     (1 3)
     (1 2))
    (6
     (1 2)
     (0 2)
     (0 1)
     (4 5)
     (3 5)
     (3 4)
     (0 3)
     (1 4)
     (2 5)
     (2 4)
     (1 3)
     (2 3))
    (7
     (1 2)
     (0 2)
     (0 1)
     (3 4)
     (5 6)
     (3 5)
     (4 6)
     (4 5)
     (0 4)
     (0 3)
     (1 5)
     (2 6)
     (2 5)
     (1 3)
     (2 4)
     (2 3))
    (8
     (0 1)
     (2 3)
     (0 2)
     (1 3)
     (1 2)
     (4 5)
     (6 7)
     (4 6)
     (5 7)
     (5 6)
     (0 4)
     (1 5)
     (1 4)
     (2 6)
     (3 7)
     (3 6)
     (2 4)
     (3 5)
     (3 4)))
  "Sorting networks for 2 to 8 elements.")

(defun sorting-network (size)
  (check-type size (integer 2 *))
  (or (cdr (assoc size sorting-networks))
      (error "No sorting network of size ~d" size)))

(defmacro sort-values/network (pred &rest values)
  (with-gensyms (swap)
    `(macrolet ((,swap (x y)
                  `(unless (funcall ,',pred ,x ,y)
                     (rotatef ,x ,y))))
       ,(let ((network (sorting-network (length values))))
          (assert network)
          (let ((temps (make-gensym-list (length values))))
            `(let ,(mapcar #'list temps values)
               ,@(loop for (x y) in network
                       collect `(,swap ,(nth x temps) ,(nth y temps)))
               (values ,@temps)))))))

(defmacro sort-values/temp-vector (pred &rest values)
  (with-gensyms (temp)
    `(let ((,temp (make-array ,(length values))))
       (declare (dynamic-extent ,temp))
       ,@(loop for i from 0 
               for v in values
               collect `(setf (svref ,temp ,i) ,v))
       ;; Keep compiler quiet.
       (setf ,temp (sort ,temp ,pred))
       (values ,@(loop for i from 0
                       for nil in values
                       collect `(svref ,temp ,i))))))

(defmacro sort-values (pred &rest values)
  "Sort VALUES with PRED and return as multiple values.

Equivalent to 

    (values-list (sort (list VALUES...) pred))

But with less consing, and potentially faster."
  ;; Remember to evaluate `pred' no matter what.
  (with-gensyms (gpred)
    `(let ((,gpred (ensure-function ,pred)))
       (declare (ignorable ,gpred)
                (function ,gpred)
                (optimize speed (safety 1) (debug 0) (compilation-speed 0)))
       ,(match values
          ((list) `(values))
          ((list x) `(values ,x))
          ;; The strategy here is to use a sorting network if the
          ;; inputs are few, and a stack-allocated vector if the
          ;; inputs are many.
          (otherwise
           (if (<= (length values) 8)
               `(sort-values/network ,gpred ,@values)
               `(sort-values/temp-vector ,gpred ,@values)))))))
