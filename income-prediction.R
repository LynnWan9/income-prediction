# preprocess data first

# read data from file
adult <- read.csv("adult.csv", header = TRUE)

# first inspect the data
head(adult)
summary(adult)
str(adult)
dim(adult)

# remove id column
adult <- adult[,-1]

# read test data set that we will make predictions on
adult_test <- read.csv("adult_test.csv", header = TRUE)
# remove id column too 
adult_test <- adult_test[, -1]

# drop records with "?"
adult[adult=="?"] <- NA
row.with.na <- apply(adult, 1, function(x){any(is.na(x))})
adult <- adult[!row.with.na,]

# divide the whole data set into training set and test set
set.seed(1)
sample_size <- floor(nrow(adult) * 0.8)
train <- sample(1:nrow(adult), sample_size)
training <- adult[train, ]
test <- adult[-train, ]
adult.test <- adult[-train, "income"]

# subgroup the data based on native_country 
# (because decision tree in r has a limit of 32 levels for categorical variables)
US <- ifelse(adult$native_country == "United-States", "YES", "No")
adult.data <- data.frame(adult, US)
# same for test data
US <- ifelse(adult_test$native_country == "United-States", "YES", "No")
adult_test <- data.frame(adult_test, US)

##Random Forest (Final Model)

# random forest for training:
set.seed(1)
library(randomForest)
rf.adult <- randomForest(income~., data = adult, subset = train, importance = TRUE)
pred.rf <- predict(rf.adult, newdata = adult[-train,])
# confusion matrix
table(pred.rf, adult.test)
# correct classification rate
(4628+984)/(4628+984+573+328) # with NA (code for getting confusion matrix with NA omitted)
(4259+971)/(4259+971+491+312) # without NA (slight improvement)

# notice that factor variables in training set and test set have different levels
# which leads the random forest procedure to an error
# address this issue here
levels(adult_test$native_country) <- levels(adult$native_country)
# prediction using given test set
pred.rf <- predict(rf.adult, newdata = adult_test)
write.table(pred.rf, "prediction4.csv", row.names=FALSE)

##Decison Tree

library(tree)
adult.tree <- tree(income ~ . -native_country, adult.data, subset = train)
# plot tree structure
plot(adult.tree)
text(adult.tree, pretty = 0)
summary(adult.tree)
pred.tree <- predict(adult.tree, adult.data[-train,], type = "class")
# confusion matrix
table(pred.tree, adult.test)
# correct classification rate
(4360+752)/(4360+752+710+211)

# prune the tree -- doesn't work, get the same results
adult.cv <- cv.tree(adult.tree, FUN = prune.misclass)
adult.cv
# 5 nodes
prune.adult <- prune.misclass(adult.tree, best = 5)
pred.tree <- predict(prune.adult, adult.data[-train,], type = "class")
table(pred.tree, adult.test)
# 8 nodes
prune.adult <- prune.misclass(adult.tree, best = 8)
pred.tree <- predict(prune.adult, adult.data[-train,], type = "class")
table(pred.tree, adult.test)

##Basic Neural Network

library(keras)
adult <- read.csv("adult.csv", header = TRUE)
# remove id column
adult <- adult[,-1]
# input test data set that we will make predictions on
adult_test <- read.csv("adult_test.csv", header = TRUE)
# remove id column
adult_test <- adult_test[, -1]
####################
# remove `fnlwgt` because it seems to have no effect on the income based on the description
adult <- adult[,-3]
adult_test <- adult_test[,-3]
# remove `education_num` because it is the same thing as `education`
adult <- adult[,-4]
adult_test <- adult_test[,-4]
###################

# change all elements to numeric
for(i in 1:13){
  adult[, i] <- as.numeric(adult[, i])
}

# one hot encode categorical variables
adult$workclass <- to_categorical(adult$workclass-1)
adult$education <- to_categorical(adult$education-1)
adult$marital_status <- to_categorical(adult$marital_status-1)
adult$occupation <- to_categorical(adult$occupation-1)
adult$relationship <- to_categorical(adult$relationship-1)
adult$race <- to_categorical(adult$race-1)
adult$sex <- to_categorical(adult$sex-1)
adult$native_country <- to_categorical(adult$native_country-1)
adult$income <- to_categorical(adult$income-1)

# build normalize function
normal <- function(x) {
  num <- x - min(x)
  denom <- max(x) - min(x)
  return (num/denom)
}

# normalize data:
adult$age <- normal(adult$age)
adult$capital_gain <- normal(adult$capital_gain)
adult$capital_loss <- normal(adult$capital_loss)
adult$hours_per_week <- normal(adult$hours_per_week)

# turn adult into a matrix
adult <- as.matrix(adult)
dimnames <- NULL

# split the data set
sample_size <- floor(nrow(adult) * 0.9)
train <- sample(1:nrow(adult), sample_size)
train_data <- adult[train, 1:106]
train_targets <- adult[train, 107:108]
test_data <- adult[-train, 1:106]
test_targets <- adult[-train, 107:108]

# design the architecture
network <- keras_model_sequential() %>%
  layer_dense(units = 200, activation = "relu", input_shape = c(1*106),
              kernel_regularizer = regularizer_l2(l = 0.001)) %>%
  layer_dense(units = 2, activation = "softmax")

# compile network
network %>% compile(
  optimizer = "rmsprop",
  loss = "binary_crossentropy",
  metrics = c("accuracy")
)

# fit the model
history <- network %>% fit(
  train_data, 
  train_targets, 
  epochs = 100, 
  batch_size = 120, 
  validation_split = 0.2)

# predict based on the test data
performance <- network %>% evaluate(test_data, test_targets)
print(performance)

#################################################################
##process test data

# change all elements to numeric
for(i in 1:12){
  adult_test[, i] <- as.numeric(adult_test[, i])
}
# one hot encode categorical variables
adult_test$workclass <- to_categorical(adult_test$workclass-1)
adult_test$education <- to_categorical(adult_test$education-1)
adult_test$marital_status <- to_categorical(adult_test$marital_status-1)
adult_test$occupation <- to_categorical(adult_test$occupation-1)
adult_test$relationship <- to_categorical(adult_test$relationship-1)
adult_test$race <- to_categorical(adult_test$race-1)
adult_test$sex <- to_categorical(adult_test$sex-1)
adult_test$native_country <- to_categorical(adult_test$native_country-1)
# normalize test data
adult_test$age <- normal(adult_test$age)
adult_test$capital_gain <- normal(adult_test$capital_gain)
adult_test$capital_loss <- normal(adult_test$capital_loss)
adult_test$hours_per_week <- normal(adult_test$hours_per_week)
# turn it into a matrix
adult_test <- as.matrix(adult_test)
dimnames <- NULL
# add one column of zero since there is one less class of native_country in the test data
new_adult_test <- matrix(0, nrow = 16281, ncol = 106)
new_adult_test[, -80] <- adult_test

# make income predictions
pred_01 <- network %>% predict_classes(new_adult_test)
prediction <- ifelse(pred_01==0, "<=50K", ">50K")
write.table(prediction, "prediction_NN1.csv", row.names=FALSE)

# plot the model loss of the training data vs the validation data
plot(history$metrics$loss, main="Model Loss", 
     xlab = "epoch", ylab="loss", col="blue", type="l")
lines(history$metrics$val_loss, col="green")
legend("topright", c("train","validation"), col=c("blue", "green"), lty=c(1,1))

# plot the model accuracy of the training data vs the validation data
plot(history$metrics$acc, main="Model Accuracy", 
     xlab = "epoch", ylab="accuracy", col="blue", type="l")
lines(history$metrics$val_acc, col="green")
legend("topright", c("train","validation"), col=c("blue", "green"), lty=c(1,1))

# summary of the neural network
summary(network)
