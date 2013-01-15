;;; neutral.lisp --- test sorters for neutrality across representations
(load "~/.sbclrc" :if-does-not-exist nil)
(require 'software-evolution)
(in-package :software-evolution)

#+complex
(advise-thread-pool-size 40)

(defvar *test* "host-test")
(defvar *prog* "blackscholes")
(defvar *orig* (from-file (make-instance 'asm) "blackscholes.s"))
(defvar *output* nil)
(defvar *work-dir* "../../sh-runner/work/")

(defun parse-stdout (stdout)
  (mapcar
   (lambda (line)
     (let ((fields (split-sequence #\Space line :remove-empty-subseqs t)))
       (cons (make-keyword (string-upcase (car fields)))
             (mapcar (lambda (c) (or (read-from-string c) c))
                     (cdr fields)))))
       (split-sequence #\Newline stdout :remove-empty-subseqs t)))

(defun evaluate (variant)
  (with-temp-file-of (file "s") (genome-string variant)
    (multiple-value-bind (stdout err-output exit)
        (shell "~a ~a ~a ~a" *test* *prog* "ASM" file)
      (declare (ignorable output err-output))
      (when (zerop exit) (parse-stdout stdout)))))

(defun multi-obj-fitness (output)
  "Calculate the total combined fitness of VARIANT based on `evaluate' output."
  (/ 1 (apply #'max (cdr (assoc :completion-time output)))))

(defun test (variant) (multi-obj-fitness (evaluate variant)))
(memoize test)

;; Sanity Check
#+sanity
(let ((orig-fit (multi-obj-fitness (evaluate *orig*))))
  (assert (and (numberp orig-fit) (> orig-fit 0))
          ((multi-obj-fitness *output*))
          "Fitness of the original is ~S but should be a number >0"
          orig-fit))

;; Optimize -- this will just run forever
#+run
(progn
  (setf (fitness *orig*) (test *orig*))
  (setf *population* (repeatedly 100 (copy *orig*)))
  (sb-thread:make-thread (lambda () (evolve test)) :name "optimizer"))

;; Save progress
#+save
(store *memoization-data* "cache.store")