
#install.packages("keras")
#Sys.setenv(RETICULATE_PYTHON = "/Users/kimnamyoun/.virtualenvs/r-tensorflow/bin/python")
Sys.setenv(RETICULATE_PYTHON = "/Users/kakao/anaconda3/bin/python")
library(keras)
library(reticulate)
library(purrr)

#install_keras(conda = auto) # keras 설치

py_config()
py_discover_config()


#use_condaenv("r-tensorflow", required = TRUE)
py_run_string("import numpy")



reticulate::py_install(packages = "keras")
reticulate::py_install(packages = "numpy")
reticulate::py_numpy_available()

is_keras_available()

parsed_corp = readRDS("./data/corpus_petition.RDS")

parsed_text = NULL
for(i in 1:length(parsed_corp$content)){
  parsed_text[i] = parsed_corp$content[[i]]$content
}

#------------------------------------------------------------------------------------------------------

parsed_text <- iconv(parsed_text, to = "UTF-8")
parsed_text <- stringi::stri_enc_toutf8(parsed_text)


tokenizer <- text_tokenizer(num_words = 30000)
tokenizer %>% fit_text_tokenizer(parsed_text)

parsed_text_check <- parsed_text %>% texts_to_sequences(tokenizer,.) %>% lapply(., function(x) length(x) > 5) %>% unlist(.)
table(parsed_text_check)
parsed_text <- parsed_text[parsed_text_check]
length(parsed_text)



skipgrams_generator <- function(text, tokenizer, window_size, negative_samples) {
  #gen <- texts_to_sequences_generator(tokenizer, sample(text))
  gen <- texts_to_sequences_generator(tokenizer, sample(parsed_text))
  function() {
    skip <- generator_next(gen) %>%
      skipgrams(
        vocabulary_size = tokenizer$num_words, 
        window_size = window_size, 
        negative_samples = 1
      )
    x <- transpose(skip$couples) %>% map(. %>% unlist %>% as.matrix(ncol = 1))
    y <- skip$labels %>% as.matrix(ncol = 1)
    list(x, y)
  }
}

embedding_size <- 128  # Dimension of the embedding vector.
skip_window <- 6       # How many words to consider left and right.
num_sampled <- 1       # Number of negative examples to sample for each word.

input_target <- layer_input(shape = 1)
input_context <- layer_input(shape = 1)


embedding <- layer_embedding(
  input_dim = tokenizer$num_words + 1, 
  output_dim = embedding_size, 
  input_length = 1, 
  name = "embedding"
)

target_vector <- input_target %>% 
  embedding() %>% 
  layer_flatten()

context_vector <- input_context %>%
  embedding() %>%
  layer_flatten()


dot_product <- layer_dot(list(target_vector, context_vector), axes = 1)
output <- layer_dense(dot_product, units = 1, activation = "sigmoid")

model <- keras_model(list(input_target, input_context), output)
model %>% compile(loss = "binary_crossentropy", optimizer = "adam")

summary(model)


#model training
model %>%
  fit_generator(
    skipgrams_generator(parsed_text, tokenizer, skip_window, negative_samples), 
    steps_per_epoch = 2256, epochs = 4
  )





library(dplyr)

embedding_matrix <- get_weights(model)[[1]]

words <- data_frame(
  word = names(tokenizer$word_index), 
  id = as.integer(unlist(tokenizer$word_index))
)

words <- words %>%
  filter(id <= tokenizer$num_words) %>%
  arrange(id)

row.names(embedding_matrix) <- c("UNK", words$word)



library(text2vec)

find_similar_words <- function(word, embedding_matrix, n = 5) {
  similarities <- embedding_matrix[word, , drop = FALSE] %>%
    sim2(embedding_matrix, y = ., method = "cosine")
  
  similarities[,1] %>% sort(decreasing = TRUE) %>% head(n)
}
find_similar_words("어린이집", embedding_matrix, n = 100)

temp =  sim2(embedding_matrix['포항', ,drop =F], y = embedding_matrix['지진', ,drop =F] , method = "cosine", norm = "l2")
dim(temp)
temp[,1] %>% sort(decreasing = TRUE) %>% head(20)
