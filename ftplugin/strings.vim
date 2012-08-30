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
    execute "python getSimilarSentences('".a:base."','".getline('.')."','".line('.')."')"
    return g:TMcomplete_completions
  endif
endfunction


"rank by similarity, then return the top n answers
function! s:DefPython()
python << EOF
import vim, re, math
from nltk.tokenize import word_tokenize
from nltk.metrics.distance import edit_distance
from nltk.stem.snowball import EnglishStemmer

stemmer=EnglishStemmer()

def getSimilarSentences(b,string,currentLineNum):
  base=getOriginal(string)
  sentences=[]
  if isLocalization(string):
    for linenum in range(len(vim.current.buffer)):
      if linenum!=int(currentLineNum)-1: # do not include current line, vim lines start from 1
        m=vim.current.buffer[linenum]
        if isLocalization(m):
          original=getOriginal(m)
          translation=getTranslation(m)
          score=getSimilarityScore(original, base)
          # change menu to show filename
          d={'word':original, 'menu':str(round(score,4)), 'info':original+"\n"+translation+""}
          sentences.append((score,d))
  sentences.sort(key=lambda x:x[0], reverse=True)
  dictstr='['
  for sentence in sentences[:min(len(sentences),10)]:
    dictstr+='{'
    for x in sentence[1]: dictstr+='"%s":"%s",' % (x, sentence[1][x])
    dictstr+='"icase":1},'
  if dictstr[-1]==',': dictstr=dictstr[:-1]
  dictstr+=']'
  #dbg("dict: %s" % dictstr)
  vim.command("let g:TMcomplete_completions=%s" % dictstr)

# similarity score for two strings, bigger is better
#levenshtein also accounts for misspellings
def getSimilarityScore(string1, string2):
  tokens1=getTokens(string1)
  tokens2=getTokens(string2)
  tokensOverlap=float(min(len(tokens1),len(tokens2)))
  tokenSim=len(set(tokens1) & set(tokens2))/tokensOverlap
  stemmed1=[stemmer.stem(x.decode("utf8")) for x in tokens1]
  stemmed2=[stemmer.stem(x.decode("utf8")) for x in tokens2]
  stemmedOverlap=float(min(len(tokens1),len(tokens2)))
  stemmedSim=len(set(stemmed1) & set(stemmed2))/stemmedOverlap
  levenshtein=edit_distance(string1, string2)
  score=(tokenSim+stemmedSim)/(levenshtein+1)
  return score

#exclude punctuation, but not stopwords (nltk.corpus.stopwords.words('english'))
def getTokens(string):
  return [x for x in word_tokenize(string.lower()) if re.match("^\W+$",x, flags=re.UNICODE) is None]

#matrix sparse coding (?)
"""(7) a. The wild child is destroying his new toy. 
b. The wild chief is destroying his new tool. 
c. The wild children are destroying their new toy. 
(8) a. Select ‘Symbol’ in the Insert menu. 
b. Select ‘Symbol’ in the Insert menu to enter a character from the symbol 
set. 
c. Select ‘Paste’ in the Edit menu. 
d. Select ‘Paste’ in the Edit menu to enter some text from the clipboard."""

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
"inoremap <silent> <Tab> <C-o>:call cursor(0,1)<cr><C-x><C-o>
