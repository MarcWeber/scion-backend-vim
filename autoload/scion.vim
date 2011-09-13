" vam#DefineAndBind('s:c','g:scion_config','{}')
if !exists('g:scion_config') | let g:scion_config = {} | endif | let s:c = g:scion_config
let s:c.sessions = get(s:c,'sessions',{})


let s:self=expand('<sfile>:h')

fun! scion#Request()
  " code
endf

" TODO implement shutdown, clean up ?
"      support quoting of arguments
fun! s:LoadPyhton(...) abort
  if !has('python')
    throw "python support required for vim-scion!"
  endif

  let py_file = s:self.'/py-helper.py'
  let mtime = getftime(py_file)

  if exists('s:py_loaded') && mtime <= s:py_loaded
    return
  endif

  " using external file which can be tested without Vim.
  exec 'pyfile '.py_file

  let s:py_loaded = getftime(py_file)
endf
call s:LoadPyhton()

fun! scion#Server(mode)
  py scion_reconnect(vim.eval("a:mode"))
endf

fun! scion#Server(mode)
  py scion_reconnect(vim.eval("a:mode"))
endf

fun! scion#RequestInternal(json) abort
  let s = json_encoding#Encode(a:json)
  py scion_server.send_receive(vim.eval('s'))
  let json = json_encoding#DecodePreserve(scion_result_str)
  if has_key(json,'Left')
    throw json.Left
  endif
  return json.Right
endf

fun! scion#Request(json) abort
  let mbConnectionId = {"Nothing": json_encoding#NULL()}
  return scion#RequestInternal([mbConnectionId, a:json])
endf

fun! scion#MaybeToStr(j)
  if has_key(a:j,"Nothing")
    return ""
  elseif has_key(a:j, "Just")
    return a:j['Just']
  else
    throw string(a:j).' is not a maybe!'
  endif
endf

fun! scion#CabalConfigToStr(thing) abort
  let c = a:thing.CabalConfig
  return scion#MaybeToStr(c.sc_buildDir).' '.string(c.sc_component).' '.c.sc_cabalFile
endf

fun! scion#CreateSession() abort
  call scion#Server("connect")
  let configs = scion#Request({"ListAvailConfigs":[split(glob("*.cabal"),"\n")[0]]})['RFileConfigs'][0]
  let config_strs = map(copy(configs),'scion#CabalConfigToStr(v:val)')
  let i = tlib#input#List('i','select config:', config_strs)
  " TODO add non cabal builds?
  let config = configs[i-1]
  let reply =  scion#Request({"CreateSession":[config]}).RSessionCreated
  let s:c.sessions.last = reply[0]
  let s:c.sessions[reply[0]] = {'ModuleSummary': map(reply[3],'v:val.ModuleSummary')}
  call scion#PopulateQF(reply[1], reply[2])
endf

fun! scion#ScionResultToErrorList(func, list) abort
  let qflist = []
  for l in a:list
    let dict = l[0]
    " l[1] is Int of Multiset
    let loc = dict['location']
    if has_key(loc, 'no-location')
      " using no-location so that we have an item to jump to.
      " ef we don't use that dummy file SaneHook won't see any errors!
      call add(qflist, { 'filename' : 'no-location'
              \ ,'lnum' : 0
              \ ,'col'  : 0
              \ ,'text' : loc['no-location']
              \ ,'type' : dict['kind'] == "error" ? "E" : "W"
              \ })
    else
      call add(qflist, { 'filename' : loc['file']
              \ ,'lnum' : loc['region'][0]
              \ ,'col'  : loc['region'][1]
              \ ,'text' : ''
              \ ,'type' : dict['kind'] == "error" ? "E" : "W"
              \ })
    endif
    for msgline in split(dict['message'],"\n")
      call add(qflist, {'text': msgline})
    endfor
  endfor
  
  call call(a:func, [qflist])
  if exists('g:haskell_qf_hook')
    exec g:haskell_qf_hook
  endif
endfun

fun! scion#PopulateQF(no_errors, list)
  call scion#ScionResultToErrorList(function('setqflist'), a:list)
endf


" if there are errors open quickfix and jump to first error (ignoring warning)
" if not close it
fun! scion#SaneHook() abort
  let list = getqflist()
  let nr = 0
  let open = 0
  let firstError = 0
  for i in getqflist()
    let nr = nr +1
    if i['bufnr'] == 0 | continue | endif
    if i['type'] == "E" && firstError == 0
      let firstError = nr
    endif
    let open = 1
  endfor
  if open
    cope " open
    " move to first error
    if firstError > 0 | exec "crewind ".firstError | endif
  else
    " if g:scion_quickfixes_always_open is set to true (non-zero) do not close
    " quickfix window even when there are not any errors.
    if exists("g:scion_quickfixes_always_open") && g:scion_quickfixes_always_open
      call setqflist([{'text' : 'No errors'}])
    else
      cclose
    endif
  endif
endf

fun! scion#BufWriteWritePost(file) abort
  " make relative:
  let file = substitute(a:file, '^'.escape(getcwd(),'\/').'.','','')
  if file[0] == '/'
    throw "making relative failed!"
  endif
  " is it contained in module summary?
  let found = 0
  if has_key(s:c.sessions,'last')
    for d in s:c.sessions[s:c.sessions.last].ModuleSummary
      if d.ms_location == file | let found = 1 | endif
    endfor
  endif
  if found
    let r = scion#Request({"FileModified":[file]}).RFileModifiedResult
    call scion#PopulateQF(r[0], r[1])
  endif
endf

" vim: set et ts=4:
