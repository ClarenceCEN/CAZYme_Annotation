require(robCompositions)
require(tibble)
require(psych)
require(reshape2)
require(dplyr)

# load colors
source(file = "G:/Dan_Lab/dietstudy_analyses-master/lib/colors/UserNameColors.R")
UserNameColors['MCTs05'] <- '#99ff00'

setwd('G:/Dan_Lab/codes/CAZyme/CAZYme_Analysis/Data_Analysis/')

food <- read.table('./data/masterdecaydiet.txt',header = T)
food$taxonomy <- as.character(food$taxonomy)

split <- strsplit(food$taxonomy,";") 

foodStrings <- sapply(split,function(x) paste(x[1:2],collapse=";"))
for (i in 1:7) taxaStrings = gsub("(;[A-z]__$)?(;NA$)?","",foodStrings,perl=T) # clean tips
food_L2 <- rowsum(food[-ncol(food)],foodStrings) 
rownames(food_L2) <- gsub(".*;L2_",'',rownames(food_L2))
#rownames(food_L2) = sapply(strsplit(food$taxonomy,";"),function(x) paste(x[1:2],collapse=";"));

#cazyme <- read.table('./data/Cazyme_total2.txt',sep='\t',header = T,row.names = 1)
#cazyme <- read.table('./data/Cazyme_total_try.txt',sep='\t',header = T,row.names = 1)


#cazyme <- cazyme[-grep('Other',rownames(cazyme)),]
#rownames(cazyme) <- gsub(".*;L4_",'',rownames(cazyme))

map <- read.table("./maps/SampleID_map.txt", sep = "\t", header = T, comment = "")

# identify soylent samples
soylent <- map[map$UserName %in% c("MCTs11", "MCTs12"),]
soylent <- as.character(soylent$X.SampleID)

#cazyme <- cazyme[,!colnames(cazyme)%in%soylent]
food_L2 <- food_L2[,!colnames(food_L2)%in%soylent]

#samples <- intersect(colnames(cazyme),colnames(food_L2))
#cazyme <- cazyme[samples]
#food_L2 <- food_L2[samples]

#cazyme_c <- as.data.frame(t(cazyme))
#cazyme_c <- rownames_to_column(cazyme_c,var = 'X.SampleID')
#cazyme_c <- merge(cazyme_c,map[c('X.SampleID','UserName')],by='X.SampleID')

food_c <- as.data.frame(t(food_L2))
food_c <- rownames_to_column(food_c,var='X.SampleID')
food_c <- merge(food_c,map[c('X.SampleID','UserName')],by='X.SampleID')

load("./data/cazyme_food_cor_ind.RData")

sigs <- lapply(cazyme_food_list, function(x) subset(x, fdr_p <= 0.2))
allsigs <- do.call("rbind", sigs)

allsigs$cazy_cat <- ifelse(grepl('AA',allsigs$cazyme),'AA',
                           ifelse(grepl('CBM',allsigs$cazyme),'CBM',
                                  ifelse(grepl('GT',allsigs$cazyme),'GT',
                                         ifelse(grepl('GH',allsigs$cazyme),'GH',
                                                ifelse(grepl('PL',allsigs$cazyme),'PL','CE')))))

allsigs$bin <- ifelse(allsigs$coef < 0, "Negative (+/-)", 
                      ifelse(allsigs$coef > 0, "Positive (+/+ or -/-)", "NA"))
allsigs$bin <- factor(allsigs$bin, levels = c("Positive (+/+ or -/-)", "Negative (+/-)"))

allsigs$pairs <- paste0(allsigs$food,'_',allsigs$cazyme)
cazyme_set <- as.character(unique(allsigs$pairs))

#different
select_cazymes <- c()
for(i in cazyme_set){
  temp_data = allsigs[allsigs$pairs==i,]
  if(length(unique(temp_data$bin))>1&& length(unique(temp_data$id))>1){
    print(i)
    select_cazymes <- c(select_cazymes,i)
  }
}

#same
select_cazymes <- c()
for(i in cazyme_set){
  temp_data = allsigs[allsigs$pairs==i,]
  if(length(unique(temp_data$bin))==1 && length(unique(temp_data$id))>1){
    print(i)
    select_cazymes <- c(select_cazymes,i)
  }
}

selected_data <- allsigs[allsigs$pairs%in%select_cazymes,]

selected_food_df <- list()
for(i in unique(selected_data$pairs)){
  print(i)

  selected_food_df[[i]] <- subset(selected_data,selected_data$pairs==i)
}

food_c$UserName <- as.character(food_c$UserName)
#cazyme_c$UserName <- as.character(cazyme_c$UserName)
cazyme_points <- cazyme_c[,!colnames(cazyme_c)%in%c("UserName","X.SampleID")]
cazyme_points <- sweep(cazyme_points,1,rowSums(cazyme_points),'/')
cazyme_points$UserName <- cazyme_c$UserName


selected_food <- list()
selected_food <- lapply(selected_food_df,function(x){
    food_c[food_c$UserName%in%as.character(x$id),colnames(food_c)%in%c("UserName",as.character(x$food))] %>%
    melt(id.vars = 'UserName',variable.name = 'food',value.name = 'weight')
})

selected_cazyme <- list()
selected_cazyme <- lapply(selected_food_df,function(x){
  cazyme_points[cazyme_points$UserName%in%as.character(x$id),colnames(cazyme_points)%in%c("UserName",as.character(x$cazyme))] %>%
    melt(id.vars = 'UserName',variable.name = 'cazyme',value.name = 'count')
})


selected_cazyme_plot <- do.call("rbind", selected_cazyme)
selected_food_plot <- do.call("rbind", selected_food)

#selected_plot <- merge(selected_food,selected_cazyme,by='UserName',all=F)
selected_plot <- bind_cols(selected_food_plot,selected_cazyme_plot)
selected_plot <- selected_plot[,names(selected_plot)!='UserName1']

selected_plot <- mutate_if(selected_plot,is.factor,as.character)
unique(selected_plot$food)

#diff
#Meatpoultry_fish_with_nonmeat_CE4
plot1 <- subset(selected_plot,selected_plot$food=='Meatpoultry_fish_with_nonmeat')
plot1 <- filter(plot1,plot1$cazyme=='CE4')

g <- ggplot(plot1,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(~UserName,scales = 'free') +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  guides(size=NULL) +
  ylab('CE4') + xlab("Meatpoultry_fish_with_nonmeat")
g
ggsave("./result/linear_plots/L2_ind/Meatpoultry_fish_with_nonmeat_CE4.pdf",
       width = 5,height = 5)

#Formulated_nutrition_beverages_energy_drinks_sports_drinks_function_GH13
plot2 <- subset(selected_plot,selected_plot$food=='Formulated_nutrition_beverages_energy_drinks_sports_drinks_function')
plot2 <- filter(plot2,plot2$cazyme=='GH13')

g <- ggplot(plot2,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(~UserName,scales = 'free') +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  guides(size=NULL) +
  ylab('GH13') + xlab("Formulated_nutrition_beverages_energy_drinks_sports_drinks_function")
g
ggsave("./result/linear_plots/L2_ind/Formulated_nutrition_beverages_energy_drinks_sports_drinks_function_GH13.pdf",
       width = 5,height = 5)


#Crackers_and_salty_snacks_from_grain_GT3
plot3 <- subset(selected_plot,selected_plot$food=='Crackers_and_salty_snacks_from_grain')
plot3 <- filter(plot3,plot3$cazyme=='GT3')

g <- ggplot(plot3,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(.~UserName,scales = "free") +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('GT3') + xlab("Crackers_and_salty_snacks_from_grain")
g
ggsave("./result/linear_plots/L2_ind/Crackers_and_salty_snacks_from_grain_GT3.pdf",
       width = 5,height = 5)

#same
#Alcoholic_beverages_GH112
plot4 <- subset(selected_plot,selected_plot$food=='Alcoholic_beverages')
plot4 <- filter(plot4,plot4$cazyme=='GH112')

g <- ggplot(plot4,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(.~UserName,scales = "free") +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('GH112') + xlab("Alcoholic_beverages")
g
ggsave("./result/linear_plots/L2_ind/Alcoholic_beverages_GH112.pdf",
       width = 5,height = 5)

#Meatpoultry_fish_with_nonmeat_GT2
plot5 <- subset(selected_plot,selected_plot$food=='Meatpoultry_fish_with_nonmeat')
plot5 <- filter(plot5,plot5$cazyme=='GT2')

g <- ggplot(plot5,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(.~UserName,scales = "free") +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('GT2') + xlab("Meatpoultry_fish_with_nonmeat")
g
ggsave("./result/linear_plots/L2_ind/Meatpoultry_fish_with_nonmeat_GT2.pdf",
       width = 5,height = 5)

#Meatpoultry_fish_with_nonmeat_GH139
plot6 <- subset(selected_plot,selected_plot$food=='Meatpoultry_fish_with_nonmeat')
plot6 <- filter(plot6,plot6$cazyme=='GH139')

g <- ggplot(plot6,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(.~UserName,scales = "free") +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('GH139') + xlab("Meatpoultry_fish_with_nonmeat")
g
ggsave("./result/linear_plots/L2_ind/Meatpoultry_fish_with_nonmeat_GH139.pdf",
       width = 5,height = 5)


#Organ_meats_sausages_and_lunchmeats_PL11
plot7 <- subset(selected_plot,selected_plot$food=='Organ_meats_sausages_and_lunchmeats')
plot7 <- filter(plot7,plot7$cazyme=='PL11')

g <- ggplot(plot7,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(.~UserName,scales = "free") +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('PL11') + xlab("Organ_meats_sausages_and_lunchmeats")
g
ggsave("./result/linear_plots/L2_ind/Organ_meats_sausages_and_lunchmeats_PL11.pdf",
       width = 5,height = 5)


#L3
setwd('G:/Dan_Lab/codes/CAZyme/CAZYme_Analysis/Data_Analysis/')

food <- read.table('./data/masterdecaydiet.txt',header = T)
food$taxonomy <- as.character(food$taxonomy)

split <- strsplit(food$taxonomy,";") 

foodStrings <- sapply(split,function(x) paste(x[1:3],collapse=";"))
for (i in 1:7) taxaStrings = gsub("(;[A-z]__$)?(;NA$)?","",foodStrings,perl=T) # clean tips
food_L3 <- rowsum(food[-ncol(food)],foodStrings) 
rownames(food_L3) <- gsub(".*;L3_",'',rownames(food_L3))
#rownames(food_L2) = sapply(strsplit(food$taxonomy,";"),function(x) paste(x[1:2],collapse=";"));


cazyme <- read.table('./data/Cazyme_total2.txt',sep='\t',header = T,row.names = 1)
#cazyme <- read.table('./data/Cazyme_total_try.txt',sep='\t',header = T,row.names = 1)


cazyme <- cazyme[-grep('Other',rownames(cazyme)),]
rownames(cazyme) <- gsub(".*;L4_",'',rownames(cazyme))

map <- read.table("./maps/SampleID_map.txt", sep = "\t", header = T, comment = "")

# identify soylent samples
soylent <- map[map$UserName %in% c("MCTs11", "MCTs12"),]
soylent <- as.character(soylent$X.SampleID)

cazyme <- cazyme[,!colnames(cazyme)%in%soylent]
food_L3 <- food_L3[,!colnames(food_L3)%in%soylent]

samples <- intersect(colnames(cazyme),colnames(food_L3))
cazyme <- cazyme[samples]
food_L3 <- food_L3[samples]

cazyme_c <- as.data.frame(t(cazyme))
cazyme_c <- rownames_to_column(cazyme_c,var = 'X.SampleID')
cazyme_c <- merge(cazyme_c,map[c('X.SampleID','UserName')],by='X.SampleID')

food_c <- as.data.frame(t(food_L3))
food_c <- rownames_to_column(food_c,var='X.SampleID')
food_c <- merge(food_c,map[c('X.SampleID','UserName')],by='X.SampleID')

cazyme_food_list <- list()

for(i in unique(food_c$UserName)){
  print(i)
  coef_v <- c()
  fdr_v <- c()
  food_v <- c()
  cazyme_v <- c()
  p_v <- c()
  id <- c()
  temp_food <- food_c[food_c$UserName==i,!colnames(food_c)%in%c('X.SampleID','UserName')]
  temp_cazyme <- cazyme_c[cazyme_c$UserName==i,!colnames(cazyme_c)%in%c('X.SampleID','UserName')]
  temp_food <- temp_food[,colSums(temp_food)!=0]
  temp_cazyme_pre <- temp_cazyme
  temp_cazyme <- sweep(temp_cazyme,1,rowSums(temp_cazyme),'/')
  temp_cazyme_pre[temp_cazyme_pre>=1] <- 1
  temp_cazyme_pre <- temp_cazyme_pre[,colSums(temp_cazyme_pre)>0.75*nrow(temp_cazyme_pre)]
  temp_cazyme <- temp_cazyme[,colnames(temp_cazyme)%in%colnames(temp_cazyme_pre)]
  temp_cor_r <- corr.test(temp_food,temp_cazyme,adjust = 'fdr',method = 'spearman')$r
  temp_cor_p <- corr.test(temp_food,temp_cazyme,adjust = 'none',method = 'spearman')$p
  temp_cor_fdr <- corr.test(temp_food,temp_cazyme,adjust = 'fdr',method = 'spearman')$p
  for(a in 1:nrow(temp_cor_p)){
    #print(a)
    for (b in 1:ncol(temp_cor_p)){
      if(!is.na(temp_cor_p[a,b])){
        coef_v <- c(coef_v,temp_cor_r[a,b])
        fdr_v <- c(fdr_v,temp_cor_fdr[a,b])
        food_v <- c(food_v,colnames(temp_food)[a])
        cazyme_v <- c(cazyme_v,colnames(temp_cazyme)[b])
        p_v <- c(p_v,temp_cor_p[a,b])
        id <- c(id,i)
      }
    }
  }
  #fdr_v <- p.adjust(p_v,method = 'fdr')
  temp_cor_df <- data.frame(food=food_v,cazyme=cazyme_v,coef=coef_v,id=id,fdr_p=fdr_v,p=p_v)
  cazyme_food_list[[i]] <- temp_cor_df
}
save(cazyme_food_list,file = './data/cazyme_food_cor_ind_L3.RData')
#save(cazyme_food_list,file = './data/cazyme_food_cor_try_L3.RData')

load('./data/cazyme_food_cor_indL3.RData')
sigs <- lapply(cazyme_food_list, function(x) subset(x, fdr_p <= 0.2))
allsigs <- do.call("rbind", sigs)

allsigs$cazy_cat <- ifelse(grepl('AA',allsigs$cazyme),'AA',
                           ifelse(grepl('CBM',allsigs$cazyme),'CBM',
                                  ifelse(grepl('GT',allsigs$cazyme),'GT',
                                         ifelse(grepl('GH',allsigs$cazyme),'GH',
                                                ifelse(grepl('PL',allsigs$cazyme),'PL','CE')))))

allsigs$bin <- ifelse(allsigs$coef < 0, "Negative (+/-)", 
                      ifelse(allsigs$coef > 0, "Positive (+/+ or -/-)", "NA"))
allsigs$bin <- factor(allsigs$bin, levels = c("Positive (+/+ or -/-)", "Negative (+/-)"))

allsigs$pairs <- paste0(allsigs$food,'_',allsigs$cazyme)
cazyme_set <- as.character(unique(allsigs$pairs))


#different
select_cazymes <- c()
for(i in cazyme_set){
  temp_data = allsigs[allsigs$pairs==i,]
  if(length(unique(temp_data$bin))>1){
    print(i)
    select_cazymes <- c(select_cazymes,i)
  }
}

#same
select_cazymes <- c()
for(i in cazyme_set){
  temp_data = allsigs[allsigs$pairs==i,]
  if(length(unique(temp_data$bin))==1 && length(unique(temp_data$id))>1){
    print(i)
    select_cazymes <- c(select_cazymes,i)
  }
}

selected_data <- allsigs[allsigs$pairs%in%select_cazymes,]

selected_food_df <- list()
for(i in unique(selected_data$pairs)){
  print(i)
  
  selected_food_df[[i]] <- subset(selected_data,selected_data$pairs==i)
}

food_c$UserName <- as.character(food_c$UserName)
#cazyme_c$UserName <- as.character(cazyme_c$UserName)
cazyme_points <- cazyme_c[,!colnames(cazyme_c)%in%c("UserName","X.SampleID")]
cazyme_points <- sweep(cazyme_points,1,rowSums(cazyme_points),'/')
cazyme_points$UserName <- cazyme_c$UserName

selected_food <- list()
selected_food <- lapply(selected_food_df,function(x){
  food_c[food_c$UserName%in%as.character(x$id),colnames(food_c)%in%c("UserName",as.character(x$food))] %>%
    melt(id.vars = 'UserName',variable.name = 'food',value.name = 'weight')
})

selected_cazyme <- list()
selected_cazyme <- lapply(selected_food_df,function(x){
  cazyme_points[cazyme_points$UserName%in%as.character(x$id),colnames(cazyme_points)%in%c("UserName",as.character(x$cazyme))] %>%
    melt(id.vars = 'UserName',variable.name = 'cazyme',value.name = 'count')
})


selected_cazyme_plot <- do.call("rbind", selected_cazyme)
selected_food_plot <- do.call("rbind", selected_food)

#selected_plot <- merge(selected_food,selected_cazyme,by='UserName',all=F)
selected_plot <- bind_cols(selected_food_plot,selected_cazyme_plot)
selected_plot <- selected_plot[,names(selected_plot)!='UserName1']

selected_plot <- mutate_if(selected_plot,is.factor,as.character)
unique(selected_plot$food)

#same
#Darkgreen_nonleafy_vegetables_GH5
plot1 <- subset(selected_plot,selected_plot$food=='Darkgreen_nonleafy_vegetables')
plot1 <- filter(plot1,plot1$cazyme=='GH5')

g <- ggplot(plot1,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(~UserName,scales = 'free') +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('GH5') + xlab("Darkgreen_nonleafy_vegetables") + ylim(c(0,0.05))
g
ggsave("./result/linear_plots/L3_ind/Darkgreen_nonleafy_vegetables_GH5.pdf",
       width = 5,height = 5)

#Frankfurters_sausages_lunchmeats_meat_spreads_PL11
plot2 <- subset(selected_plot,selected_plot$food=='Frankfurters_sausages_lunchmeats_meat_spreads')
plot2 <- filter(plot2,plot2$cazyme=='PL11')

g <- ggplot(plot2,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(~UserName,scales = 'free') +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('PL11') + xlab("Frankfurters_sausages_lunchmeats_meat_spreads")
g
ggsave("./result/linear_plots/L3_ind/Frankfurters_sausages_lunchmeats_meat_spreads_PL11.pdf",
       width = 5,height = 5)

#Darkgreen_nonleafy_vegetables_GH5
plot3 <- subset(selected_plot,selected_plot$food=='Darkgreen_nonleafy_vegetables')
plot3 <- filter(plot3,plot3$cazyme=='GH5')

g <- ggplot(plot3,aes(x=weight,y=count))+geom_point(aes(fill=UserName),alpha=0.5,size=4,shape=21)+
  facet_grid(~UserName,scales = 'free') +theme_classic() +
  stat_smooth(method = lm,color="black",size=1,se=FALSE)+
  scale_fill_manual(values = UserNameColors) +
  ylab('GH5') + xlab("Darkgreen_nonleafy_vegetables") +ylim(0,0.05)
g
ggsave("./result/linear_plots/L3_ind/Darkgreen_nonleafy_vegetables_GH5.pdf",
       width = 5,height = 5)


#L1
setwd('G:/Dan_Lab/codes/CAZyme/CAZYme_Analysis/Data_Analysis/')

food <- read.table('./data/masterdecaydiet.txt',header = T)
food$taxonomy <- as.character(food$taxonomy)

split <- strsplit(food$taxonomy,";") 

foodStrings <- sapply(split,function(x) paste(x[1:1],collapse=";"))
for (i in 1:7) taxaStrings = gsub("(;[A-z]__$)?(;NA$)?","",foodStrings,perl=T) # clean tips
food_L1 <- rowsum(food[-ncol(food)],foodStrings) 
rownames(food_L1) <- gsub(".*;L1_",'',rownames(food_L1))
#rownames(food_L2) = sapply(strsplit(food$taxonomy,";"),function(x) paste(x[1:2],collapse=";"));

load("./data/cazymes_to_keep.RData")
cazyme <- read.table('./data/Cazyme_total2.txt',sep='\t',header = T,row.names = 1)
#cazyme <- read.table('./data/Cazyme_total_try.txt',sep='\t',header = T,row.names = 1)
cazyme <- cazyme[cazymes_to_keep,]

cazyme <- cazyme[-grep('Other',rownames(cazyme)),]
rownames(cazyme) <- gsub(".*;L4_",'',rownames(cazyme))

map <- read.table("./maps/SampleID_map.txt", sep = "\t", header = T, comment = "")

# identify soylent samples
soylent <- map[map$UserName %in% c("MCTs11", "MCTs12"),]
soylent <- as.character(soylent$X.SampleID)

cazyme <- cazyme[,!colnames(cazyme)%in%soylent]
food_L1 <- food_L1[,!colnames(food_L1)%in%soylent]

samples <- intersect(colnames(cazyme),colnames(food_L1))
cazyme <- cazyme[samples]
food_L1 <- food_L1[samples]

cazyme_c <- as.data.frame(t(cazyme))
cazyme_c <- rownames_to_column(cazyme_c,var = 'X.SampleID')
cazyme_c <- merge(cazyme_c,map[c('X.SampleID','UserName')],by='X.SampleID')

food_c <- as.data.frame(t(food_L1))
food_c <- rownames_to_column(food_c,var='X.SampleID')
food_c <- merge(food_c,map[c('X.SampleID','UserName')],by='X.SampleID')

cazyme_food_list <- list()

for(i in unique(food_c$UserName)){
  print(i)
  coef_v <- c()
  fdr_v <- c()
  food_v <- c()
  cazyme_v <- c()
  p_v <- c()
  id <- c()
  temp_food <- food_c[food_c$UserName==i,!colnames(food_c)%in%c('X.SampleID','UserName')]
  temp_cazyme <- cazyme_c[cazyme_c$UserName==i,!colnames(cazyme_c)%in%c('X.SampleID','UserName')]
  temp_cor_r <- corr.test(temp_food,temp_cazyme,adjust = 'fdr',method = 'spearman')$r
  temp_cor_p <- corr.test(temp_food,temp_cazyme,adjust = 'fdr',method = 'spearman')$p
  for(a in 1:nrow(temp_cor_p)){
    #print(a)
    for (b in 1:ncol(temp_cor_p)){
      if(!is.na(temp_cor_p[a,b])){
        coef_v <- c(coef_v,temp_cor_r[a,b])
        fdr_v <- c(fdr_v,temp_cor_p[a,b])
        food_v <- c(food_v,colnames(temp_food)[a])
        cazyme_v <- c(cazyme_v,colnames(temp_cazyme)[b])
        id <- c(id,i)
      }
    }
  }
  #fdr_v <- p.adjust(p_v,method = 'fdr')
  temp_cor_df <- data.frame(food=food_v,cazyme=cazyme_v,coef=coef_v,id=id,fdr_p=fdr_v)
  cazyme_food_list[[i]] <- temp_cor_df
}
save(cazyme_food_list,file = './data/cazyme_food_cor_L1.RData')
#save(cazyme_food_list,file = './data/cazyme_food_cor_try_L3.RData')

load('./data/cazyme_food_cor_L1.RData')
sigs <- lapply(cazyme_food_list, function(x) subset(x, fdr_p <= 0.2))
allsigs <- do.call("rbind", sigs)

allsigs$cazy_cat <- ifelse(grepl('AA',allsigs$cazyme),'AA',
                           ifelse(grepl('CBM',allsigs$cazyme),'CBM',
                                  ifelse(grepl('GT',allsigs$cazyme),'GT',
                                         ifelse(grepl('GH',allsigs$cazyme),'GH',
                                                ifelse(grepl('PL',allsigs$cazyme),'PL','CE')))))

allsigs$bin <- ifelse(allsigs$coef < 0, "Negative (+/-)", 
                      ifelse(allsigs$coef > 0, "Positive (+/+ or -/-)", "NA"))
allsigs$bin <- factor(allsigs$bin, levels = c("Positive (+/+ or -/-)", "Negative (+/-)"))

allsigs$pairs <- paste0(allsigs$food,'_',allsigs$cazyme)
cazyme_set <- as.character(unique(allsigs$pairs))


select_cazymes <- c()
for(i in cazyme_set){
  temp_data = allsigs[allsigs$pairs==i,]
  if(length(unique(temp_data$bin))>1){
    print(i)
    select_cazymes <- c(select_cazymes,i)
  }
}

