;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER -*-
;;
;; This software is Copyright (c) Franz Inc. and Willem Broekema.
;; Franz Inc. and Willem Broekema grant you the rights to
;; distribute and use this software as governed by the terms
;; of the Lisp Lesser GNU Public License
;; (http://opensource.franz.com/preamble.html),
;; known as the LLGPL.

;;;; ASDF System Definitions

(in-package #:cl-user)

(eval-when (:compile-toplevel)
  (error "This ASDF file should be run interpreted."))


;;; Core systems: parser, compiler, runtime

(asdf:defsystem :clpython.package
    :description "CLPython package and readtables"
    :components ((:module "package"
                          :components ((:file "package")
                                       (:file "utils" :depends-on ("package"))
                                       (:file "readtable" :depends-on ("package"))
                                       (:file "aupprint" :depends-on ("package"))))))

(asdf:defsystem :clpython.depend
    :description "External libraries, included with minor modifications"
    :components ((:module "depend"
                          :components ((:module "cl-yacc"
                                                :components ((:file "yacc")))))))

(asdf:defsystem :clpython.parser
    :description "Python parser, code walker, and pretty printer"
    :depends-on (:clpython.package :clpython.depend)
    :components ((:module "parser"
			  :components ((:file "psetup"  )
				       (:file "grammar"  :depends-on ("psetup"))
                                       (:file "lexer"    :depends-on ("grammar"))
                                       (:file "parser"   :depends-on ("grammar" "lexer"))
                                       (:file "grammar-aclyacc" :depends-on ("grammar" "lexer" "parser"))
                                       (:file "grammar-clyacc" :depends-on ("grammar" "lexer" "parser"))
                                       (:file "ast-match")
                                       (:file "ast-util" :depends-on ("ast-match" "grammar"))
                                       (:file "walk"     :depends-on ("psetup"))
				       (:file "pprint"   :depends-on ("psetup"))))))

(asdf:defsystem :clpython.core
    :description "Python semantics and compiler"
    :depends-on (:clpython.package :clpython.parser :closer-mop)
    :components ((:module "core"
                          :serial t
                          :components ((:file "csetup"       )
                                       (:file "pydecl"       )
                                       (:file "formatstring" )
                                       (:file "classdefs"    )
                                       (:file "early-dict"   )
                                       (:file "classes"      )
                                       (:file "file"         )
                                       (:file "exceptions"   )
                                       (:file "compiler"     )
                                       (:file "generator"    )
                                       (:file "optimize"     )
                                       (:file "habitat"      )
                                       (:file "import"       )))))

(asdf:defsystem :clpython.lib
    :description "Python module library"
    :depends-on (:clpython.package :clpython.parser :clpython.core)
    :components ((:module "lib"
                          :serial t
                          :components ((:file "lsetup")
                                       (:file "array")
                                       (:file "binascii")
                                       (:file "builtins")
                                       (:file "gc")
                                       (:file "math")
                                       (:file "os")
                                       (:file "_random")
                                       (:file "re")
                                       (:file "sys")
                                       (:file "string")
				       (:file "symbol")
                                       (:file "time")))))

;;; Application systems

(asdf:defsystem :clpython.app.repl
    :description "CLPython read-eval-print loop"
    :depends-on (:clpython.core)
    :components ((:module "app"
			  :components ((:module "repl"
						:components ((:file "repl")))))))

(asdf:defsystem :clpython.app.profiler
    :description "CLPython call count profiler"
    :depends-on (:clpython.core)
    :components ((:module "app"
			  :components ((:module "profiler"
						:components ((:file "profiler")))))))

(asdf:defsystem :clpython.app
    :description "CLPython applications"
    :depends-on (:clpython.app.repl :clpython.app.profiler))


;;; The main system

(asdf:defsystem :clpython
    :description "CLPython - an implementation of Python in Common Lisp"
    :depends-on (:clpython.package :clpython.parser :clpython.core :clpython.lib clpython.app)
    :in-order-to ((asdf:test-op (asdf:load-op :clpython-test))))

(defmethod asdf:perform :after ((op asdf:test-op) (c (eql (asdf:find-system :clpython))))
  (funcall (find-symbol (string '#:run-tests) :clpython.test)))


(defvar *shown-clpython-usage* nil)

(defmethod asdf:perform :after ((op asdf:load-op) (c (eql (asdf:find-system :clpython))))
  (unless *shown-clpython-usage*
    (terpri)
    (format t "CLPython quick start guide:~%")
    (format t "  Run a string of Python code:           (~S \"for i in range(4): print i\")~%" (find-symbol (string '#:run) :clpython))
    (format t "  Run a Python file:                     (~S #p\"~~/example/foo.py\")~%" (find-symbol (string '#:run) :clpython))
    (format t "  Start the Python \"interpreter\" (REPL): (~S)~%" (find-symbol (string '#:repl) :clpython.app.repl))
    (format t "  Run the test suite:                    ~S~%~%" '(asdf:operate 'asdf:test-op :clpython))
    (setf *shown-clpython-usage* t)))


;; Check for presence of CL-Yacc and Allegro CL Yacc.

(let* ((parser-mod (let ((sys (asdf:find-system :clpython.parser)))
                     (car (asdf:module-components sys)))))
  
  #+(or) ;; Disabled whil CL-Yacc is included in CLPython/dependency.
  (let ((cl-yacc-grammar (asdf:find-component parser-mod "grammar-clyacc")))
    (defmethod asdf:perform :around ((op asdf:load-op) (c (eql cl-yacc-grammar)))
      (when (asdf:find-system :yacc nil)
        (call-next-method)
        (format t "Note: The asdf system CL-Yacc was found. ~
                 To use CL-Yacc as parser for CLPython, bind ~S to ~S.~%"
                (find-symbol (string '#:*default-yacc-version*)
                             (find-package '#:clpython.parser)) :cl-yacc)))
    (defmethod asdf:perform :around ((op asdf:compile-op) (c (eql cl-yacc-grammar)))
      (when (asdf:find-system :yacc nil)
        (call-next-method))))
  
  ;; Skip loading Allegro yacc in non-Allegro environment
  (let ((allegro-yacc-grammar (asdf:find-component parser-mod "grammar-aclyacc")))
    (defmethod asdf:perform :around ((op asdf:load-op) (c (eql allegro-yacc-grammar)))
      #+allegro (call-next-method))
    (defmethod asdf:perform :around ((op asdf:compile-op) (c (eql allegro-yacc-grammar)))
      #+allegro (call-next-method))))

;; Testing is never finished.
(defmethod asdf:operation-done-p ((o asdf:test-op)
				  (c (eql (asdf:find-system :clpython))))
  (values nil))