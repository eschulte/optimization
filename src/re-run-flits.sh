#!/bin/sh
restart(){
BASE="/nfs/adaptive/eschulte/research/epr/optimization";
num=$(ls -1tr $BASE/results/flits/|tail -1|sed 's/biased-pop-\(.*\)\.store/\1/')
cat <<EOF > re-run-flits.lisp
(require :software-evolution)
(in-package :software-evolution)
(load "optimize.lisp")
(setf *dir* "../results/flits/")
(setf *note-level* 1)
(setf *tsize* 4)
(advise-thread-pool-size 46)

(defun biased-step (pop &key (test #'<) (key #'time-wo-init) &aux result)
  "Take a whole-population biased step through neutral space."
  (flet ((new-var ()
           ;; (let ((t-pop (repeatedly *tsize* (random-elt pop))))
           ;;   (evaluate (mutate (copy (first (sort t-pop test :key key))))))
           (evaluate (mutate (copy (first (sort pop test :key key)))))))
    (loop :until (>= (length result) *psize*) :do
       (let* ((to-run (min (thread-pool-size)
                           (floor (* (- *psize* (length result)) 3))))
              (pool (progn
                      (note 1 "~&generating ~a" to-run)
                      (mapcar (lambda (var) (apply-output var (raw-output var)) var)
                              (prepeatedly to-run (new-var))))))
         (note 1 "~&keeping the fit")
         (dolist (var pool) (when (and (neutral-p var) (funcall key var))
                              (push var result)))
         (note 1 "~&(length results) ;; => ~a" (length result))))
    (subseq result 0 *psize*)))

(let ((last 0)
      (test (lambda (a b) (< (mean a) (mean b))))
      (key #'total-flits-sent))
  (setf *pop* (restore (file-for-run last)))
  (loop for n from last to 1000 do (note 1 "saving population ~d" n)
        (store *pop* (file-for-run n))
        (note 1 "generating population ~d" (1+ n))
        (setf *pop* (biased-step *pop* :test test :key key))))
EOF
sbcl --load re-run-flits.lisp &
sleep 3000;
}

restart;
while true;do
    if [ $(printf "%.0f" $(uptime|awk '{print $12}')) -lt 5 ];then
        killall -s 9 sbcl;
        sleep 300;
        restart;
    fi
    sleep 300;
done
