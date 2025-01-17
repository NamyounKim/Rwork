install.packages("topicmodels")
install.packages("LDAvis")
install.packages("servr")

library(topicmodels)
library(LDAvis)
library(servr)
library(readr)
library(tm)
library(slam)
library(dplyr)
library(NLP4kec)

# 1. 원문 데이터 및 사전 불러오기 -------------------------------------------------------------------------------------------------------------------------------------------------------
textData = readRDS("./raw_data/petitions_content_2018.RDS")

#동의어 / 불용어 사전 불러오기
stopWordDic = read_csv("./dictionary/stopword_ko.csv")
synonymDic = read_csv("./dictionary/synonym.csv")

# 만약 3주차에 저장해놓은 데이터셋을 사용하고 싶다고 readRDS로 가져오기(형태소분석 및 전처리 필요없음)
parsedData_df = readRDS("./raw_data/parsed_petition_data.RDS")
corp = readRDS("./raw_data/corpus_petition.RDS")

# 2. 형태소 분석 및 전처리---------------------------------------------------------------------------------------------------------------------------------------------------------------
#형태소 분석기 실행하기
parsedData = r_parser_r(textData$content, language = "ko", useEn = T, korDicPath = "./dictionary/user_dictionary.txt")

# 동의어 처리
parsedData = synonym_processing(parsedVector = parsedData, synonymDic = synonymDic)

## 단어간 스페이스 하나 더 추가하기 ##
parsedData = gsub(" ","  ",parsedData)

#Corpus에 doc_id를 추가하기 위한 데이터 프레임 만들기
parsedData_df = data.frame(doc_id = textData$doc_id
                           ,text = parsedData)

#Corpus 생성
corp = VCorpus(DataframeSource(parsedData_df))

#특수문자 제거
corp = tm_map(corp, removePunctuation)

#숫자 삭제
corp = tm_map(corp, removeNumbers)

#특정 단어 삭제
corp = tm_map(corp, removeWords, stopWordDic$stopword)


# 3. DTM 생성 및 Sparse Term 삭제 -------------------------------------------------------------------------------------------------------------------------------------------------------------

#Document Term Matrix 생성 (단어 Length는 2로 세팅)
dtm = DocumentTermMatrix(corp, control=list(wordLengths=c(2,Inf)))

## 한글자 단어 제외하기 ##
colnames(dtm) = trimws(colnames(dtm))
dtm = dtm[,nchar(colnames(dtm)) > 1]

#Sparse Terms 삭제
dtm = removeSparseTerms(dtm, as.numeric(0.997))

## LDA 할 때 DTM 크기 조절
#단어별 Tf-Idf 값 구하기
term_tfidf = tapply(dtm$v/row_sums(dtm)[dtm$i], dtm$j, mean) * log2(nDocs(dtm)/col_sums(dtm > 0))
term_tfidf

#박스그래프로 분포 확인
boxplot(term_tfidf, outline = T)
quantile(term_tfidf, seq(0, 1, 0.25))

# Tf-Idf 값 기준으로 dtm 크기 줄여서 new_dtm 만들기
new_dtm = dtm[,term_tfidf >= 0.1]
temp = new_dtm[row_sums(new_dtm) == 0,]
new_dtm = new_dtm[row_sums(new_dtm) > 0,]



# 4. LDA 모델링 -------------------------------------------------------------------------------------------------------------------------------------------------------------------
#분석명, 랜덤 seed, 클러스트 개수 setup
name = "petition"
SEED = 100
k = 20 #클러스터 개수 세팅

#LDA 옵션값 세팅
control_LDA_Gibbs = list(alpha = 0.1 # alpha 초기값
                         ,estimate.beta = TRUE # 각 단어의 토픽별 분포 예측 여부
                         ,delta = 0.1 # delta 초기값
                         ,verbose = 0 # 0보다 큰 값일 경우 모델링 과정 출력
                         ,prefix = tempfile() # 중간 결과물 저장 장소(임시파일)
                         ,save = 0 # 0보다 큰 값일 경우 중간 결과물 저장
                         ,keep = 0 # 0보다 큰 값일 경우 모든 iterations마다 log-likelihood 값 저장
                         ,seed = SEED # 랜던수 발생을 위한 seed 숫자 (결과물 변경 방지를 위해 보통 고정)
                         ,nstart = 1 # 랜덤  횟수
                         ,best = TRUE # 가장 좋은 모델을 선택 (likelihood값이 최대가 되는 모델)
                         ,iter = 5000 # 깁스 iteration 숫자 (반복 숫자)
                         ,burnin = 0 # 생략해서 할 iteration 숫자
                         ,thin = 2500 # 생략된 깁스 iteration 내에서 반복할 숫자
                         )

#LDA 실행
lda_tm = LDA(new_dtm, k, method = "Gibbs", control = control_LDA_Gibbs)

#토픽별 핵심단어 저장하기
term_topic = terms(lda_tm, 30)
term_topic

#문서별 토픽 번호 저장하기
doc_topic = topics(lda_tm, 1)
doc_topic_df = as.data.frame(doc_topic)
doc_topic_df$doc_id = new_dtm$dimnames[1]$Docs # 조인키 만들기 (문서 번호 가져오기)


#문서별 토픽 확률값 계산하기
doc_Prob = posterior(lda_tm)$topics
doc_Prob_df = as.data.frame(doc_Prob)

#문서별 최대 확률값 찾기
doc_Prob_df$maxProb = apply(doc_Prob_df, 1, max) # 행기준으로 max값 가져오기
doc_Prob_df$doc_id = rownames(doc_Prob_df) # 조인키 만들기 (문서 번호 가져오기)


# 3가지 데이터셋 합치기 (원문, 토픽번호, 토픽확률)
id_topic = merge(doc_topic_df, doc_Prob_df, by="doc_id")
id_topic = merge(id_topic, parsedData_df, by="doc_id", all.y = TRUE)

id_topic = id_topic %>% select(doc_id, text, doc_topic, maxProb) #코드 변경됨
id_topic = merge(id_topic, textData %>% select(doc_id, content), by="doc_id")

#단어별 토픽 확률값 출력하기
posterior(lda_tm)$terms

#토픽별 핵심 단어 파일로 출력하기
filePathName = paste0("./LDA_output/",name,"_",k,"_LDA_Result.csv")
write.table(term_topic, filePathName, sep=",", row.names=FALSE)

#문서별 토픽 번호 및 확률값 출력하기
filePathName = paste0("./LDA_output/",name,"_",k,"_DOC","_LDA_Result.csv",sep="")
write.table(id_topic, filePathName, sep=",", row.names=FALSE)


# 5. LDA결과 시각화 하기 ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# phi는 각 단어별 토픽에 포함될 확률값 입니다.
phi = posterior(lda_tm)$terms %>% as.matrix

# theta는 각 문서별 토픽에 포함될 확률값 입니다.
theta = posterior(lda_tm)$topics %>% as.matrix

# vocab는 전체 단어 리스트 입니다.
vocab = colnames(phi)

# 각 문서별 문서 길이를 구합니다.
doc_length = vector()
doc_topic_df=as.data.frame(doc_topic)

for( i in new_dtm$dimnames[[1]]){
  temp = as.character(parsedData_df[parsedData_df$doc_id == i,]$text)
  doc_length = c(doc_length, nchar(temp))
}

# 각 단어별 빈도수를 구합니다.
new_dtm_m = as.matrix(new_dtm)
freq_matrix = data.frame(ST = colnames(new_dtm_m),
                          Freq = colSums(new_dtm_m))

# 위에서 구한 값들을 파라메터 값으로 넘겨서 시각화를 하기 위한 데이터를 만들어 줍니다.
source("./Week_6/createJsonForChart_v2.R")
json_lda = createJson(phi = phi
                      , theta = theta,
                          vocab = vocab,
                          doc.length = doc_length,
                          term.frequency = freq_matrix$Freq,
                          #mds.method = jsPCA #canberraPCA가 작동 안할 때 사용
                          mds.method = jsPCA
)

# 톰캣으로 보내기
serVis(json_lda, out.dir = paste("C:/tomcat8_33/webapps/",name,"_",k,sep=""), open.browser = FALSE)
serVis(json_lda, open.browser = T) # MAC인 경우

# 예시 URL
#localhost:8080/petition_LDA_15

