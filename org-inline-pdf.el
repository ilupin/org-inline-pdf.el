;;; org-inline-pdf.el --- Inline PDF previewing for Org -*- lexical-binding: t -*-

;; Copyright (C) 2020 Shigeaki Nishina

;; Author: Shigeaki Nishina
;; Maintainer: Shigeaki Nishina
;; Created: November 30, 2020
;; URL: https://github.com/shg/org-inline-pdf.el
;; Package-Requires: ((emacs "25.1") (org "9.4"))
;; Version: 0.3
;; Keywords: org, outlines, hypermedia

;; This file is not part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see https://www.gnu.org/licenses/.

;;; Commentary:

;; Enable inline PDF preview in Org buffers.

;;; Usage:

;; You need to have pdf2svg command installed in exec-path.
;;
;;   pdf2svg: https://cityinthesky.co.uk/opensource/pdf2svg/
;;
;; Download org-inline-pdf.el and install it using package.el.
;;
;;   (package-install-file "/path-to-download-dir/org-inline-pdf.el")
;;
;; Enable this feature in an Org buffer with M-x org-inline-pdf-mode.
;; Add the following line in your init file to automatically enable
;; the feature in newly opened Org buffers.
;;
;;   (add-hook 'org-mode-hook #'org-inline-pdf-mode)
;;
;; Links to PDF files in Org buffers are now displayed inline.
;;
;; Also, when the file is exported to HTML using ox-html, PDF will be
;; embedded using img tag.  Note that PDF with img tag is not standard
;; and will be rendered only in particular browsers.  Safari.app is
;; only the one I know.
;;
;;; Code:

(require 'org)
(require 'ox-html)

(defvar org-inline-pdf-make-preview-program "pdf2svg")

(defvar org-inline-pdf-cache-directory (org-babel-temp-directory)
  "The directory that saves produced preview images.")

(defconst org-inline-pdf--org-html-image-extensions-for-file
  ;; This list is taken from the definition of the variable
  ;; org-html-inline-image-rules defined in ox-html.el and needs to be
  ;; updated if the original code is changed.
  '(".jpeg" ".jpg" ".png" ".gif" ".svg" ".webp"))

(defun org-inline-pdf--get-page-number ()
  "Determine the page number of the pdf.

You can use `#+attr_org: :page NUM' to specify the page number."
  (let* ((case-fold-search t)
         (datum (org-element-context))
         (par (org-element-lineage datum '(paragraph)))
         (attr-re "^[ \t]*#\\+attr_.*?: +.*?:page +\\(\\S-+\\)")
         (par-end (org-element-property :post-affiliated par))
         (attr-page-num
          (if (and par
                   (org-with-point-at
                       (org-element-property :begin par)
                     (re-search-forward attr-re par-end t)))
              (match-string-no-properties 1)
            "1")))
    attr-page-num))

(defun org-inline-pdf--make-preview-for-pdf (original-org--create-inline-image &rest arguments)
  "Make a SVG preview when the inline image is a PDF.
This function is to be used as an `around' advice to
`org--create-inline-image'.  The original function is passed in
ORIGINAL-ORG--CREATE-INLINE-IMAGE and arguments in ARGUMENTS."
  (let ((file (car arguments))
        (page-num (org-inline-pdf--get-page-number)))
    (apply original-org--create-inline-image
	   (cons
	    (if (member (file-name-extension file) '("pdf" "PDF"))
		(let ((svg (expand-file-name
                            (concat "org-inline-pdf-"
                                    (md5 (format "%s:%s" file page-num)))
                            org-inline-pdf-cache-directory)))
                  (when (or (not (file-exists-p svg))
                            (time-less-p (file-attribute-modification-time
                                          (file-attributes svg))
                                         (file-attribute-modification-time
                                          (file-attributes file))))
                    (call-process org-inline-pdf-make-preview-program
                                  nil nil nil file svg page-num))
		  svg)
	      file)
	    (cdr arguments)))))

;;;###autoload
(define-minor-mode org-inline-pdf-mode
  "Toggle inline previewing of PDF images in Org buffer."
  nil "" nil
  (cond
   (org-inline-pdf-mode
    (if (called-interactively-p 'interactive)
	(message "org-inline-pdf-mode enabled"))
    (add-to-list 'image-file-name-extensions "pdf")
    (advice-add 'org--create-inline-image :around #'org-inline-pdf--make-preview-for-pdf)
    (setf (alist-get "file" org-html-inline-image-rules nil t 'string=)
	  (regexp-opt (cons "pdf" org-inline-pdf--org-html-image-extensions-for-file))))
   (t
    (if (called-interactively-p 'interactive)
	(message "org-inline-pdf-mode disabled"))
    (setq image-file-name-extensions (delete "pdf" image-file-name-extensions))
    (advice-remove 'org--create-inline-image #'org-inline-pdf--make-preview-for-pdf)
    (setf (alist-get "file" org-html-inline-image-rules nil t 'string=)
	  (regexp-opt org-inline-pdf--org-html-image-extensions-for-file))
    (org-remove-inline-images)))
  (org-display-inline-images))

(provide 'org-inline-pdf)

;;; org-inline-pdf.el ends here
