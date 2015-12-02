if exists("g:loaded_twenty")
  finish
endif
let g:loaded_twenty = 1
let s:save_cpo = &cpo
set cpo&vim

command! -nargs=0 EqualTwenty call twenty#start()

let &cpo = s:save_cpo
unlet s:save_cpo
