(require 'cl)     ;; Provides common lisp emulation library.
(require 'subr-x) ;; Provides string-remove-suffix and other string functions.

;;; Refactor pjx project

;;; pjx Root directory
;;;
(setq pjx-root-directory "~/Documents/projects")

(setq pjx-current-project nil)


;;; ============== Internal functions and helpers ========== ;;

(defun pjx--path-in-dir-p (root path)
  "Check if path is in root directory."
  (string-prefix-p (expand-file-name root) (expand-file-name path)))

(defun pjx--project-list ()
  "Returns all projects directories. See full doc."
  (mapcar (lambda (p) (cons (file-name-nondirectory p) p))
          (cdr (cdr (directory-files pjx-root-directory t)))))


(defun pjx--project-path (project-name)
  "Returns a path from a given project."
  (concat (file-name-as-directory pjx-root-directory) project-name))

(defun pjx--buffer-in-project-p (project-name buf)
  "Test if a buffer belongs to a project."
  (pjx--path-in-dir-p
   (pjx--project-path project-name)
   (with-current-buffer buf
                        (or (buffer-file-name)
                            default-directory))))



;; Select a project and call the functions callback
;; as (callback <project-path>) like (callback "~/Documents/projects/test-cpp")
;;
(defun pjx--project-open-callback (callback)
  ""
  (helm
   :prompt "Project: "
   :sources  `((
                (name       . "Pjx: ")
                (candidates . ,(pjx--project-list))
                (action     . (lambda (proj) (setq pjx-current-project proj)
                                             (funcall callback proj)))
                ))))

(defun pjx--get-buffers ()
  "Return all buffers which file name or default directory is in `pjx-root-directory`"
  (cl-remove-if-not (lambda (buf)
                      (pjx--path-in-dir-p pjx-root-directory
                                        (with-current-buffer buf
                                          (or (buffer-file-name)
                                              default-directory))))
                    (buffer-list)))


(defun pjx--get-opened-projects ()
  "Return a list with all opened projects."
  (mapcar (lambda (proj) (cons proj
                               (concat (file-name-as-directory pjx-root-directory)
                                       proj)))
          (remove-if-not (lambda (p) (and p (not (string-match-p "/" p))))
           (delete "."
              (delete-dups
               (mapcar (lambda (buf)
                         (string-remove-suffix
                          "/"
                          (file-name-directory
                           (file-relative-name (with-current-buffer buf
                                                 (or (buffer-file-name)
                                                     default-directory))
                                               pjx-root-directory)))

                         )
                       (pjx--get-buffers)))))))


(defun pjx--project-select-callback (callback)
  "Select a project with helm and pass its path to the callback function."
  (helm
   :prompt "Project: "
   :sources  `((
                (name       . "Pjx: ")
                (candidates . ,(pjx--get-opened-projects))
                (action     .  callback)
                ))))


(defun pjx--get-project-of-buffer ()
  "Get the project the current buffer is associated with."
  (car (remove-if-not (lambda (proj) (pjx--buffer-in-project-p (car proj) (current-buffer)))
                      (pjx--get-opened-projects))))


(defun pjx--get-project-buffers (project-name)
  "Returns all buffers that belongs to a project."
  (remove-if-not (lambda (buf)
		   (pjx--buffer-in-project-p project-name buf))
                 (buffer-list)))


;;; ====================  User Commands ======================== ;;;

;;; =====> Commands to Open Project

(defun pjx/dired ()
  "Open root project directory."
  (interactive)
  (dired pjx-root-directory))

(defun pjx/dired-frame ()
  "Open root project directory in a new frame."
  (interactive)
  (dired-other-frame pjx-root-directory))

(defun pjx/project-open ()
  "Select project directory and open it in dired-mode."
  (interactive)
  (pjx--project-open-callback #'dired))

(defun pjx/project-open-frame ()
  "Open project in a new frame."
  (interactive)
  (pjx--project-open-callback #'dired-other-frame))

;;; ****** Commands to close a project ********************** ;;


(defun pjx/project-close ()
  "Kill all buffers associated with a selected project."
  (interactive)
  (pjx--project-select-callback
   (lambda (proj-path)

     (mapc (lambda (buf)
             (with-current-buffer buf
                   ;; (save-buffer)
                   (kill-this-buffer)
                   ))
           (pjx--get-project-buffers
            (file-name-nondirectory proj-path)))

     (let ((buf (get-file-buffer proj-path)))
       (when buf
         (with-current-buffer buf
           (kill-this-buffer)))))))

;; **** Commands to switch between project directories ****** ;;


(defun pjx/project-switch-dir ()
  "Switch to project directory"
  (interactive)
  (pjx--project-select-callback #'dired))

(defun pjx/project-switch-dir-window ()
  "Switch to project directory in other window."
  (interactive)
  (pjx--project-select-callback #'dired-other-window))

(defun pjx/project-switch-dir-frame ()
  "Switch to project directory in other window."
  (interactive)
  (pjx--project-select-callback #'dired-other-frame))

;;; *** Commands for project navigation and file selection ***** ;; 


(defun pjx/project-top ()
  "Open project top level directory."
  (dired (cdr (pjx--get-project-of-buffer))))


(defun pjx/buffer-switch ()
  (interactive)
  (helm
   :prompt "Project File: "
   :sources  `((
                (name       . "Dir: ")
                (candidates . ,(pjx--get-project-buffers
                                (pjx--get-project-of-buffer)))
                (action     . switch-to-buffer)
                ))))

;;; **** Commands to Build Project / Compile *******

(defun pjx/compile ()
  "Run compilation command at project directory."
  (interactive)
  (let ((default-directory (cdr (pjx--get-project-of-buffer))))
    (compile (read-shell-command "$ > " compile-command))))


