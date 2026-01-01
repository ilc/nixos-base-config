(require 'init-elpa)

(require-package 'helm)
(require-package 'helm-ls-git)
(require-package 'helm-ag)

(helm-mode 1)
(global-set-key (kbd "M-x") 'helm-M-x)
(global-set-key (kbd "C-x C-f") 'helm-find-files)

(setq helm-ag-base-command "rg --smart-case --no-heading --color=never --line-number")

(provide 'init-helm)
