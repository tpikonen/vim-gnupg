" Name:    gnupg.vim
" Last Change: 2020 Nov 11
" Maintainer:  James McCoy <jamessan@jamessan.com>
" Original Author:  Markus Braun <markus.braun@krawel.de>
" Summary: Vim plugin for transparent editing of gpg encrypted files.
" License: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License
"          as published by the Free Software Foundation; either version
"          2 of the License, or (at your option) any later version.
"          See https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
"
" Section: Plugin header {{{1

" guard against multiple loads {{{2
if (exists("g:loaded_gnupg") || &cp || exists("#GnuPG"))
  finish
endif
let g:loaded_gnupg = '2.7.2-dev'

" check for correct vim version {{{2
if (v:version < 702)
  echohl ErrorMsg | echo 'plugin gnupg.vim requires Vim version >= 7.2' | echohl None
  finish
endif

" Section: Autocmd setup {{{1

if (!exists("g:GPGFilePattern"))
  let g:GPGFilePattern = '*.{gpg,asc,pgp,rpad}'
endif

if (!exists("g:GPGPadFilePattern"))
  let g:GPGPadFilePattern = '*.{rpad}'
endif

augroup GnuPG
  autocmd!

  " do the decryption
  exe "autocmd BufReadCmd " . g:GPGFilePattern .  " call gnupg#init(1) |" .
                                                \ " call gnupg#decrypt(1)"
  exe "autocmd FileReadCmd " . g:GPGFilePattern . " call gnupg#init(0) |" .
                                                \ " call gnupg#decrypt(0)"

  " convert all text to encrypted text before writing
  " We check for GPGCorrespondingTo to avoid triggering on writes in
  " GPG Options/Recipient windows

  exe "autocmd BufWriteCmd,FileWriteCmd " . g:GPGPadFilePattern .
                                                \ " call s:GPGRePadRandom()"

  exe "autocmd BufWriteCmd,FileWriteCmd " . g:GPGFilePattern . " if !exists('b:GPGCorrespondingTo') |" .
                                                             \ " call gnupg#init(0) |" .
                                                             \ " call gnupg#encrypt() |" .
                                                             \ " endif"
augroup END

let s:minStartPad=1024
let s:maxStartPad=2048
let s:minEndPad=512
" Section: Highlight setup {{{1

highlight default link GPGWarning WarningMsg
highlight default link GPGError ErrorMsg
highlight default link GPGHighlightUnknownRecipient ErrorMsg

" Function: s:GPGPadRandom() {{{2
"
" Add random padding to the beginning and end of the buffer.
"
function s:GPGPadRandom()
  execute "normal! ggO"
  execute "normal! Go"
  call s:GPGReplacePadRandom()
endfunction

" Function: s:GPGRePadRandom() {{{2
"
" Check if the beginning and end of buffer have something looking like
" random padding and if so, replace it by new padding.
"
function s:GPGRePadRandom()
  let startlen = strlen(getline(1))
  let endlen = strlen(getline(line('$')))
  if (startlen < s:minStartPad || startlen > s:maxStartPad
    \ || match(getline(1), " ") > 0)
    echohl WarningMsg | echom "Padding not found at the beginning of file."
    echohl None
    execute "sleep 1"
    return
  endif
  if (endlen < s:minEndPad || match(getline(line('$')), " ") > 0)
    echohl WarningMsg | echom "Padding not found at the end of file."
    echohl None
    execute "sleep 1"
    return
  endif
  call s:GPGReplacePadRandom()
endfunction

" Function: s:GPGReplacePadRandom() {{{2
"
" Replace the first and last lines of the buffer with a random string.
" The string lenghts are such that the file length will become approximately
" a multiple of blocksize, 4096 bytes.
"
function s:GPGReplacePadRandom()
  let blocksize = 4096
  let random = system('bash -c "echo -n $RANDOM"')
  let maxran = 32767 " Maximum value of $RANDOM from bash

  let startjunklen=s:minStartPad+((s:maxStartPad - s:minStartPad)*random)/maxran
  let contlen=strlen(join(getline(2,line('$')-1)))
  let filelen=(((startjunklen + contlen + s:minEndPad)/blocksize)+1)*blocksize
  let endjunklen=filelen-(startjunklen+contlen)
  let curline=line('.')

  execute 'set nofoldenable'
  execute '1!head -c'.startjunklen.' /dev/urandom | base64 | tr --delete ''\n='' | head -c '.startjunklen
  execute '$!head -c'.endjunklen.' /dev/urandom | base64 | tr --delete ''\n='' | head -c '.endjunklen
  " Vim has teh bugs: The extra cat is needed so that the whole file is
  " filtered when calling GPGRePadRandom in BufWriteCmd autocmd.
  execute '%!cat'
  execute 'set foldenable'
  execute curline
endfunction

" Section: Commands {{{1

command! GPGViewRecipients call gnupg#view_recipients()
command! GPGEditRecipients call gnupg#edit_recipients()
command! GPGViewOptions call gnupg#view_options()
command! GPGEditOptions call gnupg#edit_options()
command! GPGPadRandom call s:GPGPadRandom()
command! GPGRePadRandom call s:GPGRePadRandom()

" Section: Menu {{{1

if (has("menu"))
  amenu <silent> Plugin.GnuPG.View\ Recipients :GPGViewRecipients<CR>
  amenu <silent> Plugin.GnuPG.Edit\ Recipients :GPGEditRecipients<CR>
  amenu <silent> Plugin.GnuPG.View\ Options :GPGViewOptions<CR>
  amenu <silent> Plugin.GnuPG.Edit\ Options :GPGEditOptions<CR>
endif

" vim600: set foldmethod=marker foldlevel=0 :
