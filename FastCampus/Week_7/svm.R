#package check & install & load
library(dplyr)
library(stringi)
library(tm)
library(pROC)
library(slam)
library(gmodels)
library(e1071)
library(klaR)
library(readr)
library(NLP4kec)

#형태소 분석기 실행하기
parsedData = file_parser_r(path = "./raw_data/Blog_TrainingSet_Spam.xlsx"
                           ,language = "ko"
                           ,korDicPath = "./dictionary/user_dictionary.txt")

# 예측 변수값 가져오기
target_val = read_csv("./raw_data/training_target_val.csv")

#동의어 / 불용어 사전 불러오기
stopWordDic = read_csv("./dictionary/stopword_ko.csv")
synonymDic = read_csv("./dictionary/synonym.csv")

# 1. Text Pre-processing ---------------------------------------------------------------------------------------

# 동의어 처리
parsedData = synonym_processing(parsedVector = parsedData, synonymDic = synonymDic)

#Corpus에 doc_id를 추가하기 위한 데이터 프레임 만들기
parsedData_df = data.frame(doc_id = seq(1:length(parsedData))
                           ,text = parsedData)

#Corpus 생성
corp = VCorpus(DataframeSource(parsedData_df))

#특수문자 제거
corp = tm_map(corp, removePunctuation)


#특정 단어 삭제
corp = tm_map(corp, removeWords, stopWordDic$stopword)


#Document Term Matrix 생성 (단어 Length는 2로 세팅)
dtm = DocumentTermMatrix(corp, control=list(wordLengths=c(2,Inf)))

## 한글자 단어 제외하기 ##
colnames(dtm) = trimws(colnames(dtm))
dtm = dtm[,nchar(colnames(dtm)) > 1]

#Sparse Terms 삭제
dtm = removeSparseTerms(dtm, as.numeric(0.98))

#Covert to Dataframe
dtmDf = as.data.frame(as.matrix(dtm))

#중복 Column 삭제
dtmDf = dtmDf[,!duplicated(colnames(dtmDf))]


# 2. 학습 데이터 준비하기 ------------------------------------------------------------------------------------------
#DtmDf에 정답표 붙이기
dtmDf$target = target_val$spam_yn

#Traing Set, Test Set 만들기
trainingSet = dtmDf[1:8000,] #Training 데이터 8,000개
testSet = dtmDf[8001:nrow(dtmDf),] #Test 데이터 2,012개

dtmDf$target
tapply(dtmDf$target, dtmDf$target, length)

# 타켓 변수 범주형타입으로 변경
trainingSet$target = as.factor(trainingSet$target)


# 3. SVM 모델링 및 결과 확인 ----------------------------------------------------------------------------------------
svmModel = svm(target ~ . 
               , data = trainingSet
               , type = "C-classification"
               , kernel="linear"
               , gamma=0.1
               , cost=1)

svmModel = readRDS("./Week_7/svm_model.RDS") # 미리 저장해놓은 모델 불러오기

#Spam 문서 예측하기
svmPred =  predict(svmModel, newdata = testSet[,1:(ncol(testSet)-1)])

#Test 데이터 확인하기
tapply(testSet$target, testSet$target, length)

#예측 결과 확인하기
svm_pred_result = CrossTable(table(testSet$target, svmPred), prop.chisq=FALSE)

#정확도 계산하기
(svm_pred_result$t[1,1] + svm_pred_result$t[2,2]) / nrow(testSet)


# 4. 새로운 데이터(정답지가 없는) 분류 -----------------------------------------------------------------------------------

# 새로운 문서 형태소 분석 실행하기
newData = file_parser_r(path = "./raw_data/Blog_TestSet_Spam.xlsx"
                        ,language = "ko"
                        ,korDicPath = "./dictionary/user_dictionary.txt")

# 동의어 처리
newData = synonym_processing(parsedVector = newData, synonymDic = synonymDic)

## 단어간 스페이스 하나 더 추가하기 ##
newData = gsub(" ","  ", newData)

#Corpus 생성
newCorp = VCorpus(VectorSource(newData))

#특수문자 제거
newCorp = tm_map(newCorp, removePunctuation)

#특정 단어 삭제
newCorp = tm_map(newCorp, removeWords, stopWordDic$stopword)

#Document Term Matrix 생성 (단어 Length는 2로 세팅)
newDtm = DocumentTermMatrix(newCorp, control=list(removeNumbers=FALSE, wordLengths=c(2,Inf)))

## 한글자 단어 제외하기 ##
colnames(newDtm) = trimws(colnames(newDtm))
newDtm = newDtm[,nchar(colnames(newDtm)) > 1]

#Covert to Dataframe
newDtmDf = as.data.frame(as.matrix(newDtm))

#중복 Column 삭제
newDtmDf = newDtmDf[,!duplicated(colnames(newDtmDf))]

## Training Set Column과 newDtmDf 의 Column을 동일하게 만들어주는 처리
newDtmDf = newDtmDf[,colnames(newDtmDf) %in% colnames(trainingSet)] # 서로 같은 컬럼만 추출

add_col = trainingSet[,!colnames(trainingSet) %in% colnames(newDtmDf)] # trainingSet과 다른 컬럼 추출
add_column_nm = colnames(add_col) 

forAdd = data.frame(matrix(0, ncol=length(add_column_nm), nrow=nrow(newDtmDf))) # trainingSet과 다른 컬럼을 갖는 0으로 구성된 데이터 셋 만들기
colnames(forAdd)= add_column_nm # 컬럼명 부여하기

newDtmDf = cbind(newDtmDf, forAdd) # newDtmDf에 붙여주기

# 새로운 문서 Spam 문서 예측하기
svmPred_new = predict(svmModel, newDtmDf)

# 새로운 문서 예측결과 확인하기기
test_target_val = read_csv("./raw_data/test_target_val.csv")
svmPred_new_df = data.frame(pred = svmPred_new, original = test_target_val$spam_yn)
svmPred_new_result = CrossTable(table(svmPred_new_df$original, svmPred_new_df$pred), prop.chisq=FALSE)
(svmPred_new_result$t[1,1] + svmPred_new_result$t[2,2]) / length(newData)
