" source this scipt while writing on the other .vim files
" then they'll be reloaded after writing

augroup UpdateVimFiles
  autocmd BufWritePost autoload/haskellcomplete.vim,ftplugin/haskell.vim exec 'source '.expand('%')
augroup end
