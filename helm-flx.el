;;; helm-flx.el --- Sort helm candidates by flx score -*- lexical-binding: t -*-

;; Copyright (C) 2014, 2015 PythonNut

;; Author: PythonNut <pythonnut@pythonnut.com>
;; Keywords: convenience, helm, fuzzy, flx
;; Version: 20151013
;; URL: https://github.com/PythonNut/helm-flx
;; Package-Requires: ((emacs "24") (helm "1.7.9") (flx "0.5"))

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package implements intelligent helm fuzzy sorting, provided by flx.

;; You can install the package by either cloning it yourself, or by doing M-x package-install RET helm-flx RET.

;; After that, you can enable it by putting the following in your init file:

;;     ;; For best results, load this before you load helm.
;;     (helm-flx-mode +1)

;; See the README for more info.

;;; Code:

(eval-when-compile
  (with-demoted-errors "Byte-compile: %s"
    (require 'helm)
    (require 'flx)))

(defgroup helm-flx nil
  "Sort helm candidates by flx score"
  :group 'convenience
  :prefix "helm-flx-")

(defcustom helm-flx-limit 5000
  "The maximum number of helm candidates (N) to sort. If the number of
candidates is greater than this number, only sort the first N (presorted by length). Set to nil to sort all candidates."
  :type 'number
  :group 'flx-isearch)

(defvar helm-flx-cache nil
  "Stores the current flx cache for helm-flx.")

(defvar helm-flx-old-helm-fuzzy-sort-fn nil
  "Stores the old value of helm-fuzzy-sort-fn")
(defvar helm-flx-old-helm-fuzzy-matching-highlight-fn nil
  "Stored the old value of helm-fuzzy-matching-highlight-fn")

(with-eval-after-load 'flx
  (setq helm-flx-cache (flx-make-string-cache #'flx-get-heatmap-file)))

(defun helm-flx-fuzzy-matching-sort (candidates _source &optional use-real)
  (require 'flx)
  (if (string= helm-pattern "")
      candidates
    (let ((num-cands (length candidates))

          ;; no need to branch on use-real for every candidate
          (scored-string-fn (if use-real
                                (lambda (cand)
                                  (if (consp cand)
                                      (cdr cand)
                                    cand))
                              (lambda (cand)
                                (if (consp cand)
                                    (car cand)
                                  cand)))))
      (mapcar #'car
              (sort (mapcar
                     (lambda (cand)
                       (cons cand
                             (or (car (flx-score (funcall scored-string-fn
                                                          cand)
                                                 helm-pattern
                                                 helm-flx-cache))
                                 0)))
                     (if (or (not helm-flx-limit)
                             (> helm-flx-limit helm-candidate-number-limit)
                             (< num-cands helm-flx-limit))
                         candidates
                       (let ((seq (sort candidates
                                        (lambda (c1 c2)
                                          (< (length (funcall scored-string-fn
                                                              c1))
                                             (length (funcall scored-string-fn
                                                              c2))))))
                             (end (min helm-flx-limit
                                       num-cands))
                             (result nil))
                         (while (and seq
                                     (>= (setq end (1- end)) 0))
                           (push (pop seq) result))
                         result)))
                    (lambda (c1 c2)
                      (> (cdr c1)
                         (cdr c2))))))))

(defun helm-flx-fuzzy-highlight-match (candidate)
  (require 'flx)
  (let* ((pair (and (consp candidate) candidate))
         (display (if pair (car pair) candidate))
         (real (cdr pair)))
    (with-temp-buffer
      (insert display)
      (goto-char (point-min))
      (if (string-match-p " " helm-pattern)
          (dolist (p (split-string helm-pattern))
            (when (search-forward p nil t)
              (add-text-properties
               (match-beginning 0) (match-end 0) '(face helm-match))))
        (dolist (index (cdr (flx-score
                             (substring-no-properties display)
                             helm-pattern helm-flx-cache)))
          (with-demoted-errors
              (add-text-properties
               (1+ index) (+ 2 index) '(face helm-match)))))
      (setq display (buffer-string)))
    (if real (cons display real) display)))

;;;###autoload
(define-minor-mode helm-flx-mode
  "helm-flx minor mode"
  :init-value nil
  :group 'helm-flx
  :global t
  (if helm-flx-mode
      (progn (setq helm-flx-old-helm-fuzzy-sort-fn
                   (bound-and-true-p helm-fuzzy-sort-fn))
             (setq helm-flx-old-helm-fuzzy-matching-highlight-fn
                   (bound-and-true-p helm-fuzzy-matching-highlight-fn))
             (setq helm-fuzzy-sort-fn
                   #'helm-flx-fuzzy-matching-sort)
             (setq helm-fuzzy-matching-highlight-fn
                   #'helm-flx-fuzzy-highlight-match))
    (setq helm-fuzzy-sort-fn
          (or helm-flx-old-helm-fuzzy-sort-fn
              #'helm-fuzzy-matching-default-sort-fn))
    (setq helm-fuzzy-matching-highlight-fn
          (or helm-flx-old-helm-fuzzy-matching-highlight-fn
              #'helm-fuzzy-default-highlight-match))))

(provide 'helm-flx)

;;; helm-flx.el ends here
