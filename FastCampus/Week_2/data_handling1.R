
## 1. 벡터, 리스트, 매트릭스, 데이터 프레임 생성 ------------------------------------------------------------------------------------------------------------------------------------------------
# 1-1. Vector 만들기
a = c(1,2,4)
c = c("aa","bb","cc")

# 1-2. List 만들기
b = list("test", 5, a)

# 1-3. Matrix 만들기
mat = matrix( c(2, 4, 3, 1, 5, 7), # 데이터
            nrow=2,         # 행의수
            ncol=3,         # 열의수 
            byrow = TRUE)   # 행기준으로 만들기

# 1-4. 데이터프레임 만들기
df = data.frame(col1 = c(1,2,3),
                col2 = c("A","B","C")
                )

# 1-5. Matrix를 데이터프레임으로 변경
mat_df = as.data.frame(mat)

# 1-6. 데이터프레임을 Matrix로 변경
df_matrix = as.matrix(df)

## 2. 데이터 프레임 정보 가져오기 ------------------------------------------------------------------------------------------------------------------------
# 2-1. 데이터 프레임형식의 샘플 데이터 가져오기
data("iris")
iris

data("Cars93")
Cars93

# 2-2. 데이터 형식 확인하기
str(iris)
str(Cars93)

# 2-8.행, 열개수 확인하기
nrow(iris)
ncol(iris)


head(iris)
head(iris, 10)

# 2-9. Vector, List 의 길이 구하기
length(iris[,1])
length(iris[1,])

## 3. 데이터 접근하기 ------------------------------------------------------------------------------------------------------------------------------------------------

# 3-1. 특정 열값만 가져오기
iris[,1] # 첫번째 열(column) 값 가져오기
iris[,2] # 두번째 열(column) 값 가져오기
iris[,1:3] # 첫번째부터 세번째 열 가져오기

iris$Sepal.Length # Sepal.Length라는 이름을 갖는 열(column) 값 가져오기
subset(iris, select = c(Sepal.Length)) # Subset 함수로 Sepal.Length 라는 이름을 갖는 열(column) 값 가져오기
subset(iris, select = c(Sepal.Length, Sepal.Width)) # Subset 함수로 Sepal.Length, Sepal.Width 라는 이름을 갖는 열(column) 값 가져오기

# 3-2.특정 행값만 가져오기
iris[1,] # 첫번째 행(row) 값 가져오기
iris[2,] # 두번째 행(row) 값 가져오기
iris[1:3,] # 첫번째부터 세번째 행 가져오기
iris[4,2] # 네번째 행의 2번째 열 값 가져오기 

subset(iris, iris$Sepal.Width > 4) # Sepal.Width 가 4보다 큰 행만 가져오기 

# 3-3. 특정 행, 열값만 가져오기
iris[3,4] # 3번째 행의 4번째 열 값 가져오기
subset(iris, iris$Sepal.Width > 4,  select = c(Sepal.Length)) # Sepal.Width 가 4보다 큰 행에서 Sepal.Length 열만 가져오기

# 3-4. 서로 같은 값(하나만) 매칭하여 가져오기
subset(iris, iris$Species == "setosa")

# 3-5. 서로 같은 값들 매칭하여 가져오기
subset(iris, iris$Species %in% c("setosa","virginica"))


## 4. 데이터 추가 및 컬럼명 변경하기 ---------------------------------------------------------------------------------------------------------------------------------------------

# 4-1. 행 추가하기
addRow = list(10, 20, 10, 20, "virginica")
iris = rbind(iris, addRow)

# 4-2. 열 추가하기
addCol = sample(1:151, 151)
iris = cbind(iris, addCol)


# 4-3. 열 이름 불러오기
colnames(iris)[2]

# 4-4. 열 이름 바꾸기
colnames(iris)[6] = "ChangeColName" # 6번째 열이름 바꾸기
colnames(iris)

colnames(iris) = c("a","b","c","d","e","f") # 모든 열이름 바꾸기
colnames(iris)


## 5. 데이터 조작하기 ---------------------------------------------------------------------------------------------------------------------------------------------

# 5-1. Group by (특정값 기준으로 집계하기)
tapply(iris$Sepal.Length, iris$Species, mean) # Species별로 Sepal.Length의 평균 구하기


# 5-2. Data 조인(join)
df1 = data.frame(id = c(1,2,3,4,5,6), 
                 name= c("Jonh", "Jessica", "Tom","Rodrio","James","Alessia"))

df2 = data.frame(id = c(2,4,6,8), location=c("Seoul","LA", "Paris","Rome"))

# Inner Join
merge(df1, df2, by="id")

# Left Outer Join
merge(df1, df2, by="id", all.x = TRUE)

# Right Outer Join
merge(df1, df2, by="id", all.y = TRUE) 

# 조인키가 서로 다를때
merge(df1, df2, by.x = "dd", by.y = "aa")


## 6. 데이터 내보내기, 가져오기 ---------------------------------------------------------------------------------------------------------------------------------------------
install.packages("readr")
library(readr)

# 6-1. 데이터 내보내기
write_csv(iris, path = "./iris.csv", col_names = T)
write_delim(iris, path = "./iris.txt", delim = "|", col_names = T)


# 6-2. 데이터 읽어오기
iris_2 = read_csv("./iris.csv")





