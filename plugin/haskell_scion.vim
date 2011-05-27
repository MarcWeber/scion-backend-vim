if !exists('g:scion_config')
  let g:scion_config = {}
  " let g:scion_config['use_default_scion_cabal_dist_dir'] = 0
endif

" you use this:
command! ScionCreateSession echo scion#CreateSession()

command! ScionServerLog py vim.command("exec 'e 'fnameescape(%s)" % vimQuote(scion_server.server_logfile_path))

command! ScionStart call scion#Server("connect")
command! ScionStop call scion#Server("disconnect")
command! ScionReconnect call scion#Server("reconnect")

command! ScionConnectionInfo echo scion#Request({"ConnectionInfo":[]})

" you should use ScionStop instead
command! ScionQuitServer echo scion#Request({"QuitServer":[]})
command! ScionListSupportedLanguages echo scion#Request({"ListSupportedLanguages":[]})
command! ScionListAvailConfigs echo scion#Request({"ListAvailConfigs":[split(glob("*.cabal"),"\n")[0]]})


" TODO arg?
" command! ScionFileModified echo scion#Request({"FileModified":[expand('%')]})

silent! au! SCION
augroup SCION
  autocmd VimLeavePre * call scion#Server('disconnect')
  autocmd BufWritePost *.*hs call scion#BufWriteWritePost(expand('%'))
augroup end


" TODO
" CreateSession SessionConfig
