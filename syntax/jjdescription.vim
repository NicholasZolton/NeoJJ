" Vim syntax file
" Language:	jj (Jujutsu) commit/describe message
" Maintainer:	Neojj

if exists("b:current_syntax")
  finish
endif

scriptencoding utf-8

syn case match
syn sync minlines=50
syn sync linebreaks=1

if has("spell")
  syn spell toplevel
endif

" Include diff syntax for inline diffs
syn include @jjdescriptionDiff syntax/diff.vim
syn region jjdescriptionDiff start=/\%(^diff --\%(git\|cc\|combined\) \)\@=/ end=/^\%(diff --\|$\|@@\@!\|[^[:alnum:]\ +-]\S\@!\)\@=/ fold contains=@jjdescriptionDiff

" First line is the summary (like git commit subject)
if get(g:, 'jjdescription_summary_length', 1) > 0
  exe 'syn match   jjdescriptionSummary	"^.*\%<' . (get(g:, 'jjdescription_summary_length', 72) + 1) . 'v." contained containedin=jjdescriptionFirstLine nextgroup=jjdescriptionOverflow contains=@Spell'
endif
syn match   jjdescriptionOverflow	".*" contained contains=@Spell
syn match   jjdescriptionBlank	"^.\+" contained contains=@Spell
syn match   jjdescriptionFirstLine	"\%^.*" nextgroup=jjdescriptionBlank,jjdescriptionComment skipnl

" JJ: comment lines
syn match   jjdescriptionComment	"^JJ:.*"

" Headers within comments: "Change ID:", "This commit contains..."
syn match   jjdescriptionHeader	"\%(^JJ: \)\@<=\S.*:$" contained containedin=jjdescriptionComment
syn match   jjdescriptionHeader	"\%(^JJ: \)\@<=Change ID:.*" contained containedin=jjdescriptionComment
syn match   jjdescriptionHeader	"\%(^JJ: \)\@<=This commit contains.*" contained containedin=jjdescriptionComment
syn match   jjdescriptionHeader	"\%(^JJ: \)\@<=Commands:$" contained containedin=jjdescriptionComment

" Change IDs and commit hashes in comments
syn match   jjdescriptionHash	"\<\x\{8,}\>" contains=@NoSpell display

" File status within comments (M, A, D, R prefixes)
syn match   jjdescriptionType	"\%(^JJ:\s\+\)\@<=[MADR]\ze " contained containedin=jjdescriptionComment nextgroup=jjdescriptionFile skipwhite
syn match   jjdescriptionFile	"\S.*" contained contains=@NoSpell

" Keybinding hints in Commands section
syn match   jjdescriptionKeybind	"<[^>]\+>" contained containedin=jjdescriptionComment

" Highlight links
hi def link jjdescriptionSummary		Keyword
hi def link jjdescriptionComment		Comment
hi def link jjdescriptionHash		Identifier
hi def link jjdescriptionHeader		PreProc
hi def link jjdescriptionType		Type
hi def link jjdescriptionFile		Constant
hi def link jjdescriptionOverflow	Error
hi def link jjdescriptionBlank		Error
hi def link jjdescriptionKeybind	Special

let b:current_syntax = "jjdescription"
