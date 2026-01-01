(require 'init-elpa)
(require-package 'company)
(require 'company)

(use-package lsp-mode :commands lsp)
(use-package lsp-ui :commands lsp-ui-mode)

(use-package ccls
  :hook ((c-mode c++-mode objc-mode cuda-mode) .
         (lambda () (require 'ccls) (lsp))))

(provide 'init-lsp)
