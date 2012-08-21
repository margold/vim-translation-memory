set omnifunc=TMComplete
set completeopt=longest,menuone,preview

if !has('python')
  echo "Error: Required vim compiled with +python"
  finish
endif

function! TMComplete(findstart, base)
  if a:findstart==1
    return 0
  else
    execute "python getSimilarSentences('".a:base."','".getline('.')."')"
    return g:TMcomplete_completions
  endif
endfunction


"rank by similarity, then return the top n answers
function! s:DefPython()
python << EOF
import vim
#from nltk.tokenize import word_tokenize

def getSimilarSentences(b,string):
  base=getOriginal(string)
  sentences=[]
  if isLocalization(string):
    for m in vim.current.buffer:
      if isLocalization(m):
        original=getOriginal(m)
        translation=getTranslation(m)
        d={'word':original, 'menu':'<filename>', 'info':original+"\n<"+translation+">"}
        sentences.append((getSimilarityScore(original, base),d))
  sentences.sort(key=lambda x:x[0], reverse=True)
  dictstr='['
  for sentence in sentences[:min(len(sentences),2)]:
    dictstr+='{'
    for x in sentence[1]: dictstr+='"%s":"%s",' % (x, sentence[1][x])
    dictstr+='"icase":1},'
  if dictstr[-1]==',': dictstr=dictstr[:-1]
  dictstr+=']'
  #dbg("dict: %s" % dictstr)
  vim.command("let g:TMcomplete_completions=%s" % dictstr)

# similarity score for two strings, bigger is better
def getSimilarityScoreNLTK(string1, string2):
  sentence1=set(word_tokenize(string1.lower()))
  sentence2=set(word_tokenize(string2.lower()))
  score = len(sentence1 & sentence2)/min(len(sentence1),len(sentence2))
  return score

def getSimilarityScore(string1, string2):
  sentence1=set(string1.strip('",.:?!').split())
  sentence2=set(string2.strip('",.:?!').split())
  score = len(sentence1 & sentence2)/min(len(sentence1),len(sentence2))
  return score
 
# utility functions for working with .strings files
def isLocalization(line):
  line=line.strip()
  if len(line)==0:
    return False
  elif line.startswith('/*') and line.endswith('/*'): #REGEX
    return False
  elif "=" not in line:
    return False
  else:
    return True

def getOriginal(line):
  return line.split("=")[0].strip().replace('"','')
 
def getTranslation(line):
  return line.split("=")[1].strip().replace('"','') 
  
EOF
endfunction

call s:DefPython()

"put the cursor at the beginning of the line before omnicompletion
"omnicompletion with TAB
inoremap <silent> <Tab> <C-o>:call cursor(0,1)<cr><C-x><C-o>
