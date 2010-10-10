if !exists('g:scion_config')
  let g:scion_config = {}
  " let g:scion_config['use_default_scion_cabal_dist_dir'] = 0
endif
" probably more commands should be moved from haskell.vim into this file so
" that the commands can be run even when not editing a haskell file.

fun! s:LoadComponentCompletion(A,L,P)
  let beforeC= a:L[:a:P-1]
  let word = matchstr(beforeC, '\zs\S*$')

  let result = []
  for item in haskellcomplete#EvalScion(1,'list-cabal-components',{'cabal-file': haskellcomplete#CabalFile()})
    if has_key(item, 'library')
      call add(result, 'library') " there can only be one
    elseif has_key(item, 'executable')
      call add(result, 'executable:'. item['executable'])
    else
      " component type File will never be returned ?
      throw "unexpected item ".string(item)
    endif
  endfor
  call filter(result,'v:val =~ '.string('^'.a:A))
  return result
endf

fun! s:LoadComponentScion(...)
  let result = haskellcomplete#LoadComponent(1,a:000)
  echo haskellcomplete#ScionResultToErrorList('load component finished: ','setqflist', result)

  " start checking file on buf write
  if !exists('g:dont_check_on_buf_write')
    augroup HaskellScion
      au BufWritePost *.hs,*.hsc,*.lhs silent! BackgroundTypecheckFile
    augroup end
  endif
endf


" arg either "library", "executable:name" or "file:Setup.hs"
" no args: file:<current file>
command! -nargs=? -complete=customlist,s:LoadComponentCompletion
  \ LoadComponentScion
  \ call s:LoadComponentScion(<f-args>)

command! -nargs=* -complete=file WriteSampleConfigScion
  \ echo haskellcomplete#WriteSampleConfig(<f-args>) | e .scion-config

command! -nargs=0 DumpNameDBScion
  \ echo haskellcomplete#EvalScion(1, 'dump-name-db', {})

" use this output for completion (TODO)?
command! -nargs=0 -buffer TopLevelNamesScion
  \ echo haskellcomplete#EvalScion(1, 'top-level-names', {})

" use this output for novigation (TODO)?
command! -nargs=0 -buffer OutlineScion
  \ echo haskellcomplete#EvalScion(1, 'outline', {})
" merge commands add optional arg? I'm too lazy
command! -nargs=0 -buffer OutlineNoTrimScion
  \ echo haskellcomplete#EvalScion(1, 'outline', {'trimFile': json#False()})

" for debugging:
command! -nargs=0 -buffer DumpModuleGraph
  \ echo haskellcomplete#EvalScion(1, 'dump-module-graph', {})
