


#' Import genotype data in the correct format for network construction
#' @import data.table
#' @description For network construction based on both genomic correlations
#' as well as epistatic interactions a genotype matrix has to be
#' created, consisting of one numeric value per SNP, per individual. This function
#' takes Plink output (1,2-coding) to create the genotype matrix which can be used
#' to calculate genomic correlations or epistatic interaction effects 
#' @usage generate.genotype(ped, tped, gwas_id=tped[,2], pvalue=0.05, id.select=ped[,2],gwas_p=NULL,major_freq=0.95)
#' @param ped The ped file (.ped) is an input file from Plink: The PED file is a
#' white-space (space or tab) delimited file: the first six columns are mandatory:
#' Family ID, Idividual ID, Paternal ID, Maternal ID, 
#' Sex (1=male; 2=female;other=unknown) and Phenotype. The IDs are alphanumeric: 
#' the combination of family and individual ID should uniquely identify a person.
#' A PED file must have 1 and only 1 phenotype in the sixth column.
#' The phenotype can be either a quantitative trait or an affection status 
#' column: PLINK will automatically detect which type
#' (i.e. based on whether a value other than 0, 1, 2 or the missing genotype 
#' code is observed). SNPs are 1,2-coded (1 for major allele,2 for minor allele) 
#' For more information: http://pngu.mgh.harvard.edu/~purcell/plink/data.shtml#ped
#' @param tped The tped file (.tped) is a transposed ped file, from Plink. 
#' This file contains the SNP and genotype information where one row is a SNP.
#' The first 4 columns of a TPED file are the same as a 4-column MAP file.
#' Then all genotypes are listed for all individuals for each particular SNP on 
#' each line. Again, SNPs are 1,2-coded.
#' @param gwas.id  A vector of all SNPs in the GWAS
#' @param pvalue A value for the cutoff of the SNPs which should be remained 
#' in the matrix, based on the pvalue resulting from the GWAS. Default value
#' is 0.05
#' @param id.select If requested, a subset of individuals can be 
#' selected (e.g. extremes). If nothing inserted, all individuals are in the
#' output
#' @param gwas.p **optional** A vector of the p-values corresponding to 
#' the gwas_id vector. If assigned, will select snps based on the pvalue
#' parameter with a default value of 0.05.
#' @param major.freq Maximum major allele frequency allowed in each variant. 
#' Default value is 0.95.
#' @param fast.read If true will use fread from the data.table package to read
#' the files. This is much faster than read.table, but requires consistent delimeters
#' in the ped and tped file, and a maximum of approximately 950.000 colums in the ped
#' file. This can be increased by changing the stack size (do this only if you
#' know what you are doing)
#' @return A genotype dataframe and the corresponding vector of passing snps in a vector.
#' The genotype data frame has a row for each individual and a column
#'  for each SNP. SNPs are 1,1.5,2 coded: 1 for homozygous for the major 
#'  allele, 1.5 for heterozygous, and 2 for homozygous for the minor allele. 
#'  Missing values are NA coded. 
#' @details There is so much to be said
#' @references Lisette J.A. Kogelman and Haja N.Kadarmideen (2014). 
#' Weighted Interaction SNP Hub (WISH) network method for building genetic
#' networks for complex diseases and traits using whole genome genotype data.
#' BMC Systems Biology 8(Suppl 2):S5. 
#' http://www.biomedcentral.com/1752-0509/8/S2/S5.
#' @examples
#' generate.genotype(ped, tped, gwas_id, gwas_p, pvalue, id.select,gwas_p,major_freq)
#' 
#' @export
#' 
#' 
#' 
generate.genotype <- function(ped,tped,snp.id=NULL, pvalue=0.05,id.select=NULL,gwas.p=NULL,major.freq=0.95,fast.read=T) {
  if (fast.read == T){
    message("loading ped file")
    ped <- fread(ped,data.table=F)
    message("loading tped file")
    tped <- fread(tped,data.table=F)
  }
  else {
    message("loading ped file")
    ped <- read.table(ped)
    message("loading tped file")
    tped <- read.table(tped)
  }
  if ((dim(ped)[1] != (dim(tped)[2]-4)/2) && ((dim(ped)[2]-6)/2 != (dim(tped)[1]))){
    stop("Error: ped-file and tped file dimensions do not fit, make sure file delimiters are consistent")
  } 
  if(is.null(snp.id)){
    snp.id <- tped[,2]
  }
  if(is.null(id.select)){
    id.select <- ped[,2]
  }
  if(is.null(gwas.p)){
    genotype <- matrix(nrow=length(c(id.select)),ncol=length(c(snp.id)))
    rownames(genotype) <- id.select
    colnames(genotype) <- snp.id
    if (length(c(snp.id))==length(c(tped[,2]))){
      snps <- c(1:dim(tped)[1])
    }
    else {
      snps<-which(tped[,2]%in%snp.id)  
    }
    if (length(c(id.select))==length(c(ped[,2]))){
      ids <- c(1:dim(ped)[1])
      ped_trim <- as.matrix(ped[ids,c(rep(2*snps,each=2)-(1:(2*length(snps)))%%2+6)])
    }
    else {
      ids<-which(ped[,2]%in%id.select)
      ped_trim <- as.matrix(ped[ids,c(sort(rep(2*snps,each=2)-(1:(2*length(snps)))%%2)+6)])
    }
    ped_trim[ped_trim==0] <- NA
    for (i in 1:(dim(genotype)[2])){
      genotype[,i] <- rowMeans((ped_trim[,c(2*i-1,2*i)]))
    }
  }
  if(!(is.null(gwas.p))){
    # In case of p-value filtering we want the input SNP IDs to match the pvalue vector
    if(length(as.vector(gwas.p))!=length(as.vector(snp.id))){
      stop("Gwas P-values not same length as SNP IDs")
    }  
    snp.id <- as.vector(snp.id)
    original_length<-length(snp.id)
    snp.id <- snp.id[as.vector(gwas.p) <= pvalue & !(is.na(as.vector(gwas.p)))]
    new_length<-length(snp.id) 
    snp_counts<-paste(as.character(new_length),as.character(original_length), sep = "/") 
    message(paste(snp_counts, "passed P-value threshold"), sep=" ")
    genotype <- matrix(nrow=length(c(id.select)),ncol=length(c(snp.id)))
    rownames(genotype) <- id.select
    colnames(genotype) <- snp.id
    if (length(c(snp.id))==length(c(tped[,2]))){
      snps <- c(1:dim(tped)[1])
      if (length(c(id.select))==length(c(ped[,2]))){
        ids <- c(1:dim(ped)[1])
        ped_trim <- ped[ids,c(rep(2*snps,each=2)-(1:(2*length(snps)))%%2+6)]
      }
      else {
        ids<-which(ped[,2]%in%id.select) 
        ped_trim <- ped[ids,c(sort(rep(2*snps,each=2)-(1:(2*length(snps)))%%2)+6)]
      }
    }
    else {
      snps<-which(tped[,2]%in%snp.id)  
      if (length(c(id.select))==length(c(ped[,2]))){
        ids <- c(1:dim(ped)[1])
        ped_trim <- as.matrix(ped[ids,c(rep(2*snps,each=2)-(1:(2*length(snps)))%%2+6)])
      }
      else {
        ids<-which(ped[,2]%in%id.select) 
        ped_trim <- as.matrix(ped[ids,c(sort(rep(2*snps,each=2)-(1:(2*length(snps)))%%2)+6)])
      }
    }  
    ped_trim[ped_trim==0] <- NA
    for (i in 1:(dim(genotype)[2])){
      
      genotype[,i] <- rowMeans((ped_trim[,c(2*i-1,2*i)]))
    }
  }
  #Ensuring that we only get variants with enough variation. We remove variants with no minor alleles or/and with a majore allele frequency over 0.95(default)
  passing_snps <- which((colSums((genotype == 2),na.rm = T)*colSums((genotype == 1),na.rm = T)) > 0 & colSums(genotype == 1,na.rm = T) < (dim(genotype)[1]*major.freq))
  genotype <- genotype[,passing_snps]
  return(genotype)
}





#' This function calculates the row coordinates for splitting triangular sub
#' matrices of quadratic matrices into approximately equally sized partitions
#' for use in in dividing correlation calculations into equal size for 
#' parallelization    
#' @description Internal function for splitting triangular matrices into
#' approximately equal parts
#' @usage triangular_split(n, split)
#' @param n Row and Column length of the n by n matrix the triangular matrix
#' originates from
#' @param split Number of partitions to split the triangular matrix in
#' @return A matrix of row coordinates used for splitting
#' @examples
#' triangular_split(1000,5)
#' 
#' @export


triangular_split <- function(n,split) {
  if (split == 1){
    boundaries<-matrix(0,nrow=split,ncol=2)
    boundaries[1,1] <- 1
    boundaries[1,2] <- n
  }
  else {
    total_count<-(n*n-n)/2
    splits <- total_count/split
    total <- splits
    row <- c()
    for (i in 1:(split-1)){
      temp_row<-((2*n-1)-sqrt((2*n-1)^2-8*total))/2
      temp_row <- floor(temp_row)
      row <- c(row,temp_row)
      total <- total+splits
    }
    row<-as.vector(c(0,row,n))
    boundaries<-matrix(0,nrow=split,ncol=2)
    for (i in 1:split){
      boundaries[i,1] <- row[i]+1
      boundaries[i,2] <- row[i+1]
    }
  }
  return(boundaries)
}

#' This function calculates the epistatic correlations in a subset of 
#' a matrix space based on coordiantes
#' @description Internal function for calculating epsitatic correlations
#' in sub-matrices
#' @usage partial_correlations(genotype,genotype_rev,phenotype,coords,model)
#' @param genotype Dataframe with the genotype information, resulting from 
#' the function generate.genotype(). Make sure that the dataframe contains the 
#' same individuals as in the phenotype-file, and that those are in the 
#' same order.
#' @param genotype_rev Same as genotpye but with reversed genotype coding
#' @param phenotype Dataframe with the rows correspinding to the individuals
#' in the analysis,and columns for the different measured phenotypes and 
#' fixed/random factors. Phenotypes should be continous variables. 
#' @param coords Matrix of row split coordinates for subseting input space
#' @param model Specification controlling if MM or Mm directed interaction
#' model is used.
#' @return Epsitatic correlations and P-values for the selected set or subset
#' of the data
#' @examples
#' partial_correlations <- function(genotype,genotype_rev,phenotype,coords,model)
#' 
#' @export

partial_correlations <- function(genotype,genotype_rev,phenotype,coords,model=1){
  n=dim(genotype)[2]
  data_matrix <- matrix(0,nrow = 2*(coords[2]-coords[1]+1),ncol=dim(genotype)[2])
  matrix_row <- 0
  if (model==1){
    for (i in coords[1]:coords[2]){
      matrix_row <- matrix_row+1
      if (i < n){
        for (j in (i+1):n){
          tmp_model = fastLm(phenotype ~ I(genotype[,i])+I(genotype[,j])+I(genotype[,i]*genotype[,j]))
          data_matrix[(matrix_row*2-1):(matrix_row*2),j]<-c(tmp_model$coefficients[length(tmp_model$coefficients)],summary(tmp_model)$coefficients[dim(summary(tmp_model)$coefficients)[1],4])
        }
      }
    }
  }
  if (model==2){
    for (i in coords[1]:coords[2]){
      matrix_row <- matrix_row+1
      if (i < n){
        for (j in (i+1):n){
          tmp_model = fastLm(phenotype ~ I(genotype[,i])+I(genotype[,j])+I(genotype[,i]*genotype_rev[,j]))
          data_matrix[(matrix_row*2-1):(matrix_row*2),j]<-c(tmp_model$coefficients[length(tmp_model$coefficients)],summary(tmp_model)$coefficients[dim(summary(tmp_model)$coefficients)[1],4])
        }
      }
    }
  }
  return(data_matrix)
}


#' Calculate the epistatic interaction effect between SNP pairs to construct a 
#' WISH network using a genotype data frame created from genarate.genotype()
#' @import doParallel
#' @import foreach
#' @import RcppEigen
#' @description A WISH network can be built based on epistatic interaction 
#' effects between SNP pairs. Those interaction effects are calculated using
#' linear models. 
#' @usage epistatic.correlation(phenotype, genotype, parallel,test,simple)
#' @param phenotype Dataframe with the rows correspinding to the individuals
#' in the analysis,and columns for the different measured phenotypes and 
#' fixed/random factors. Only give one phenotype column at a time. Phenotypes
#' should be continous variables. Make sure that the dataframe contains the same
#' individuals as in the genotype-file, and that those are in the same order.
#' @param genotype Dataframe with the genotype information, resulting from 
#' the function generate.genotype(). Make sure that the dataframe contains the 
#' same individuals as in the phenotype-file, and that those are in the 
#' same order.
#' @param parallel Number of cores to use for parallel execution in the function 
#' registerDoParallel()
#' @param test True or False value indicating if a test run is being perform.
#' If True will calculate the expected time it will take for the full analysis
#' based on calculating 100.000 models with the setting chosen
#' @param simple True or false value indicating if only a major/major and
#' minor/minor directed interaction model are tested (simple=T) or if if 
#' interactions on the major/minor minor axis are tested as well, with the 
#' best one of the two being selected (simple=F).
#' @return A list of two matrices. The first matrix gives the epistatic
#' interaction effects between all the SNP-pairs which were in the input 
#' genotype data) and selected with the pvalue from the GWAS results. 
#' The second matrix are the corresponding pvalues of the parameter 
#' estimates of the epistatic interactions. 
#' @references Lisette J.A. Kogelman and Haja N.Kadarmideen (2014). 
#' Weighted Interaction SNP Hub (WISH) network method for building genetic
#' networks for complex diseases and traits using whole genome genotype data.
#' BMC Systems Biology 8(Suppl 2):S5. 
#' http://www.biomedcentral.com/1752-0509/8/S2/S5.
#' @examples
#' epistatic.correlation(phenotype,genotype,parallel,test,simple)
#' 
#' @export

epistatic.correlation <- function(phenotype,genotype,parallel=1,test=T,simple=T){
  registerDoParallel(parallel)
  phenotype < as.matrix(phenotype)
  n<-ncol(genotype)
  coords<-triangular_split(n,parallel)
  if(is.data.frame(genotype)){
    genotype[] <- lapply(genotype, as.numeric)
  }
  if (simple==F || test==T){
    genotype_rev <- genotype
    decide_1<-(genotype_rev==1)
    decide_2<-(genotype_rev==2)
    genotype_rev[decide_1] <- 2
    genotype_rev[decide_2] <- 1
    rm(decide_1)
    rm(decide_2)
    genotype_rev <- as.data.frame(genotype_rev)
  }
  if (test==T && n > 315) {
    message("Running Test")
    message("Estimating run time based on ~100.000 models")
    start.time <- Sys.time()
    test_coords<-triangular_split(316,parallel)
    snp_matrix <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype[,1:316],genotype_rev[,1:316],phenotype,test_coords[j,],model=1)
      return(subset)
    }
    end.time <- Sys.time()
    time<-as.numeric(end.time-start.time,units="hours")
    model_time<-(((n^2-n)/2)/((316^2-316)/2))*time
    model_time <- round(model_time,digits = 2)
    model_time<-as.character(model_time)
    estimate<-paste(paste("The estimated run time for the simple model is",model_time),"hours",sep=" ")
    message(estimate)
    snp_matrix <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype[,1:316],genotype_rev[,1:316],phenotype,test_coords[j,],model=2)
      return(subset)
    }
    end.time <- Sys.time()
    time<-as.numeric(end.time-start.time,units="hours")
    model_time<-(((n^2-n)/2)/((316^2-316)/2))*time
    model_time <- round(model_time,digits = 2)
    model_time<-as.character(model_time)
    estimate<-paste(paste("The estimated run time for the full model is",model_time),"hours",sep=" ")
    message(estimate)
  }
  else if (test==T && n <= 315){
    message("Data size too small for testing, running normal analysis")
    snp_matrix <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype,genotype_rev,phenotype,coords[j,],model=1)
      return(subset)
    }
    # Running opposite minor/major co-linearity model
    snp_matrix_rev <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype,genotype_rev,phenotype,coords[j,],model=2)
      return(subset)
    }
  }
  else if (test==F && simple==F) {
    snp_matrix <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype,genotype_rev,phenotype,coords[j,],model=1)
      return(subset)
    }
    # Running opposite minor/major co-linearity model
    snp_matrix_rev <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype,genotype_rev,phenotype,coords[j,],model=2)
      return(subset)
    }
  }
  if (test == F && simple==F || (test==T && n <= 315)){
    # Transposing and filling out the correlation and pvalue matrix
    epi_cor <- snp_matrix[seq(1,nrow(snp_matrix)-1,2),]
    epi_pvalue <-   snp_matrix[seq(2,nrow(snp_matrix),2),]
    rm(snp_matrix)
    epi_cor_t <- t(epi_cor)
    epi_pvalue_t <- t(epi_pvalue)
    diag(epi_cor_t) <- 1
    diag(epi_pvalue_t) <- 1
    epi_cor_t[upper.tri(epi_cor_t)]<- epi_cor[upper.tri(epi_cor)]
    epi_pvalue_t[upper.tri(epi_pvalue_t)]<- epi_pvalue[upper.tri(epi_pvalue)]
    epi_cor_t_1 <- epi_cor_t
    epi_pvalue_t_1 <- epi_pvalue_t
    epi_cor_t_1[is.na(epi_cor_t_1)] <- 0
    epi_pvalue_t_1[is.na(epi_pvalue_t_1)] <- 1
    # Opposite assumption correlation and pvalue matrix
    epi_cor <- snp_matrix_rev[seq(1,nrow(snp_matrix_rev)-1,2),]
    epi_pvalue <-   snp_matrix_rev[seq(2,nrow(snp_matrix_rev),2),]
    rm(snp_matrix_rev)
    epi_cor_t <- t(epi_cor)
    epi_pvalue_t <- t(epi_pvalue)
    diag(epi_cor_t) <- 1
    diag(epi_pvalue_t) <- 1
    epi_cor_t[upper.tri(epi_cor_t)]<- epi_cor[upper.tri(epi_cor)]
    epi_pvalue_t[upper.tri(epi_pvalue_t)]<- epi_pvalue[upper.tri(epi_pvalue)]
    epi_cor_t_2 <- epi_cor_t
    epi_pvalue_t_2 <- epi_pvalue_t
    epi_cor_t_2[is.na(epi_cor_t_2)] <- 0
    epi_pvalue_t_2[is.na(epi_pvalue_t_2)] <- 1
    #Picking the correct model assumption based on lowest pvalue
    decider_matrix <- epi_pvalue_t_1-epi_pvalue_t_2
    epi_pvalue_t <- epi_pvalue_t_1
    epi_pvalue_t[0 < decider_matrix] <- epi_pvalue_t_2[0 < decider_matrix]
    epi_cor_t <- epi_cor_t_1
    epi_cor_t[0 < decider_matrix] <- epi_cor_t_2[0 < decider_matrix]
    colnames(epi_pvalue_t) <- colnames(genotype)
    rownames(epi_pvalue_t) <- colnames(genotype)
    colnames(epi_cor_t) <- colnames(genotype)
    rownames(epi_cor_t) <- colnames(genotype)
    output <-list(epi_pvalue_t,epi_cor_t)
    names(output)<-c("Pvalues","Coefficients")
    return(output)
  }
  else if (test==F && simple==T) {
    snp_matrix <- foreach(j = 1:parallel, .combine='rbind', .inorder=T, .verbose=F) %dopar% {
      subset <- partial_correlations(genotype,genotype_rev,phenotype,coords[j,],model=1)
      return(subset)
    }
    epi_cor <- snp_matrix[seq(1,nrow(snp_matrix)-1,2),]
    epi_pvalue <-   snp_matrix[seq(2,nrow(snp_matrix),2),]
    epi_cor_t <- t(epi_cor)
    epi_pvalue_t <- t(epi_pvalue)
    diag(epi_cor_t) <- 1
    diag(epi_pvalue_t) <- 1
    epi_cor_t[upper.tri(epi_cor_t)]<- epi_cor[upper.tri(epi_cor)]
    epi_pvalue_t[upper.tri(epi_pvalue_t)]<- epi_pvalue[upper.tri(epi_pvalue)]
    colnames(epi_pvalue_t) <- colnames(genotype)
    rownames(epi_pvalue_t) <- colnames(genotype)
    colnames(epi_cor_t) <- colnames(genotype)
    rownames(epi_cor_t) <- colnames(genotype)
    output <-list(epi_pvalue_t,epi_cor_t)
    names(output)<-c("Pvalues","Coefficients")
    return(output)
  }
}
#' Visualization of pairwise chromosome epistatic interactions on a genome wide level
#' @description Visualization of the genome wide chromosome pairwise relative strength
#' of epistatic interaction, ranging from 1 (strongest) to -1 (weakest).
#' The strength is based on the 90th percentile quantile (default) of stastistical
#' significance of epistatic interaction between all interactions in each
#' chromosome pair, scaled to 1 to -1. 
#' @import corrplot
#' @usage genome.interaction(tped,correlations)
#' @param tped The tped file used in generate.genotype(). The SNPs must
#' be sorted by chromosome, matching the order of the SNPs in the correlation 
#' matrices. 
#' @param correlations List of epistatic correlations and p-values genrated by
#' epistatic.correlation()
#' @param quantile Number from 0 to 1 indicating which quantile to base the
#' visualization on. 
#' @return Outputs a plot visualizing the chromosome interaction map
#' @examples
#'  genome.interaction(tped,correlations)
#' 
#' @export


genome.interaction <- function(tped,correlations,quantile=0.9) {
  new_P <- (1-correlations$Pvalues)
  message("loading tped file")
  tped <- fread(tped,data.table=F)
  map<-tped[tped[,2] %in% rownames(correlations$Pvalues),1:2]
  counter = 0
  ends <- c()
  chr_list <- c()
  for (i in map[,1]){
    if (counter == 0){
      counter <- counter + 1
      starts <- 1
      chr <- i
      chr_list <- c(chr_list,chr)
    }
    else {
      if (chr == i){
        counter <- counter + 1 
        if (counter == dim(map)[1]){
          ends <- c(ends,counter)
        }
      }
      if (chr != i){
        chr <- i
        chr_list <- c(chr_list,chr)
        ends <- c(ends,counter)
        counter <- counter + 1 
        starts <- c(starts,counter)
      }
    }
  }
  coord_splits<-cbind(starts,ends)
  visualization_matrix <- matrix(nrow = length(starts),ncol = length(starts))
  colnames(visualization_matrix) <- chr_list
  rownames(visualization_matrix) <- chr_list
  for (i in 1:length(starts)){
    for (j in 1:length(starts)){
      subset <- c(new_P[coord_splits[i,1]:coord_splits[i,2],coord_splits[j,1]:coord_splits[j,2]])
      subset <- abs(subset)
      visualization_matrix[i,j] <- quantile(subset,quantile)
    }
  }
  visualization_matrix <- 2*(visualization_matrix-min(visualization_matrix))/(max(visualization_matrix)-min(visualization_matrix))-1
  corrplot(visualization_matrix, type="upper",title= "Pairwise Chromosome Interaction Map",mar=c(0,0,2,0))
}


#' Visualization of chromosome pairwise region epistatic interaction strength, based on 
#' statistical significance 
#' @description Visualization of chromosome pairwise region epistatic interaction strength, based on 
#' statistical significance. The value is based of the most signficant epistatic interaction in each
#' region pair, ranging from 1 ( strongest) to 0 (weakest). By defaulty chromosomes are separated into
#' 1 Mb regions, but if SNPs are more spaced out that this it will adjust to the smallest region that fit
#' the data.  
#' @import heatmap3
#' @usage pairwise.chr.map(chr1,chr2,tped,correlations)
#' @param chr1 The name of the first chromosome in the comparison, matching the name
#' from the tped file
#' @param chr2 The name of the second chromosome in the comparison, matching the name
#' from the tped file
#' @param tped The tped file used in generate.genotype(). The SNPs must
#' be sorted by chromosome and position on the chromosome, matching the order of the SNPs in the correlation 
#' matrices. 
#' @param span Region in bp. Default is 1 Mb (10^6)
#' @param correlations List of epistatic correlations and p-values genrated by
#' epistatic.correlation()
#' @return Outputs a plot visualizing the pairwise chromosome region interaction
#' @examples
#'  pairwise.chr.map("1","2",tped,correlations)
#' 
#' @export


pairwise.chr.map <- function(chr1,chr2,tped,correlations,span=10^6) {  
  new_P <- (1-correlations$Pvalues)
  message("loading tped file")
  tped <- fread(tped,data.table=F)
  total_map <- tped[tped[,2] %in% rownames(correlations$Pvalues),c(1,4)]
  total_map[,2] <- as.numeric(total_map[,2])
  map <-total_map[total_map[,1] == chr1,]
  first_snp <- map[1,2]
  last_snp <- map[dim(map)[1],2]
  #size <- round((last_snp-first_snp)/span,digits=0)
  progress <- 1
  ends <- c()
  for (snp in map[,2]){   
    if ( snp < (first_snp+progress*span)) {
      starts <- 1
      row <- 1
    }
    else {
      while (snp > first_snp+(progress+1)*span) {
        progress <- progress +1
      }
      print("what")
      ends <- c(ends,row)
      row <- row +1
      starts <- c(starts,row)
      progress <- progress + 1
    }
  }
  ends<- c(ends,dim(map)[1])
  chromosome_choords1 <- cbind(starts,ends)
  chromosome_choords1 <- chromosome_choords1 + which(total_map[,1] == chr1)[1]-1
  map <-total_map[total_map[,1] == chr2,]
  first_snp <- map[1,2]
  last_snp <- map[dim(map)[1],2]
  #size <- round((last_snp-first_snp)/10^6,digits=0)
  progress <- 1
  ends <- c()
  for (snp in map[,2]){   
    if ( snp < (first_snp+progress*10^6)) {
      print("!t")
      starts <- 1
      row <- 1
    }
    else {
      while (snp > first_snp+(progress+1)*10^6) {
        progress <- progress +1
      }
      print("what")
      ends <- c(ends,row)
      row <- row +1
      starts <- c(starts,row)
      progress <- progress + 1
    }
  }
  ends<- c(ends,dim(map)[1])
  chromosome_choords2 <- cbind(starts,ends)
  chromosome_choords2 <- chromosome_choords2 + which(total_map[,1] == chr2)[1]-1
  visualization_matrix <- matrix(nrow = dim(chromosome_choords1)[1],ncol = dim(chromosome_choords2)[1])
  colnames(visualization_matrix) <- 1:(dim(chromosome_choords2)[1])
  rownames(visualization_matrix) <- 1:(dim(chromosome_choords1)[1]) 
  for (i in 1:dim(chromosome_choords1)[1]){
    for (j in 1:dim(chromosome_choords2)[1]){
      subset <- c(new_P[chromosome_choords1[i,1]:chromosome_choords1[i,2],chromosome_choords2[j,1]:chromosome_choords2[j,2]])
      subset <- abs(subset)
      visualization_matrix[i,j] <- max(subset)
      
    }
  }
  xlabel<-paste("Chromosome=",as.character(chr2),", N-regions=",as.character(dim(chromosome_choords2)[1]))
  ylabel<-paste("Chromosome=",as.character(chr1),", N-regions=",as.character(dim(chromosome_choords1)[1]))
  heatmap3(visualization_matrix,scale="none",main="Pairwise Chromosomal Interaction",Rowv = NA,Colv = NA,xlab=xlabel,ylab=ylabel ,labRow=c("start",rep("",dim(chromosome_choords1)[1]-2),"end"),labCol=c("start",rep("",dim(chromosome_choords2)[1]-2),"end"))
}


#' Visualization of chromosome pairwise region epistatic interaction strength, based on 
#' statistical significance 
#' @description Visualization of chromosome pairwise region epistatic interaction strength, based on 
#' statistical significance. The value is based of the most signficant epistatic interaction in each
#' region pair, ranging from 1 ( strongest) to 0 (weakest). By defaulty chromosomes are separated into
#' 1 Mb regions, but if SNPs are more spaced out that this it will adjust to the smallest region that fit
#' the data.  
#' @import WGCNA
#' @import flashClust
#' @usage generate.modules(correlations)
#' @param correlations List of epistatic correlations and p-values genrated by
#' epistatic.correlation()
#' @param power Powers to test for creating scale free network. Only change if the default
#' values don't work
#' @param n.snps Number of SNPs to select. SNPs are selected by connectivity, so 500 will
#' select the top 500 most connected Snps. Default is to use all
#' @param minClusterSize Minimum module (cluster) size. Default, is 50, but changing this may
#' be recommended in case of sparse SNPs  
#' @param type Type of network to generate. Default is "unsigned", can be "signed" or "signed hybrid"
#' @param threads Number of threads to use if parallelization is possible.
#' @return Plots the network connectivity and the scale and SNP tree clustering with modules found. 
#' Returns a named list with all the data generated:
#' \itemize{
#'  \item{"SNPs"}{SNPs used in the analysis and their correlations}
#'  \item{"connectivity"}{The connectivity matrix of the SNPs}
#'  \item{"adjMat"}{The adjacency matrix of the SNPs}
#'  \item{"dissTom"}{The dissimilarity TOM}
#'  \item{"genetree"}{The clustering object used for the genetree}
#'  \item{"modules"}{The module numbers for each SNP, in order of the SNP matrix}
#'  \item{"modulcolors"}{The colors used in the modules for each SNP}
#'  \item{"power.estimate"}{The power estimate to generate a scale free network}
#' }
#' @examples
#'  generate.modules(correlations)
#' 
#' @export


generate.modules <- function(correlations,values="Coefficients",power=c(seq(1,10,0.1),c(12:22)),n.snps=dim(correlations$Coefficients)[1],minClusterSize=50,type="unsigned",threads=1) {
  enableWGCNAThreads(threads)
  if (values=="Pvalue"){
    corr <- (1-correlations$Pvalues)*(correlations$Coefficients/abs(correlations$Coefficients))
  }
  if (values=="Coefficient"){
    temp_corr<-correlations$Coefficients
    temp_corr[temp_corr < 0] <- 0
    temp_corr <- temp_corr/(max(temp_corr))
    corr <- temp_corr
    temp_corr <- correlations$Coefficients
    temp_corr[temp_corr > 0] <- 0
    temp_corr <- temp_corr/(abs(min(temp_corr)))
    corr[temp_corr < 0] <- temp_corr[temp_corr < 0]
  }
  sft = pickSoftThreshold(corr, powerVector = c(seq(1,10,0.1),c(12:22)), verbose = 5)
  connectivity <- adjacency.fromSimilarity(corr, power=sft$powerEstimate,type=type)
  sizeGrWindow(10,5)
  par(mfrow=c(1,2))
  hist(connectivity,xlab="connectivity")
  scaleFreePlot(connectivity)
  par(mfrow=c(1,1))
  #select SNPs for network construction based on connectivity
  select.snps <- corr[rank(-colSums(connectivity),ties.method="first")<=n.snps,rank(-colSums(connectivity),ties.method="first")<=n.snps ]
  select.snps[,c(1:ncol(select.snps))] <- sapply(select.snps[,c(1:ncol(select.snps))], as.numeric)
  #create adjacency matrix (correlation matrix raised to power beta)
  adjMat <- adjacency.fromSimilarity(select.snps,power=sft$powerEstimate,type=type)
  #calculate dissimilarity TOM
  dissTOM <- 1-(TOMsimilarity(adjMat))
  #create gene dendrogram based on diss TOM
  genetree <- flashClust(as.dist(dissTOM), method="average")
  #cut branches of the tree= modules
  dynamicMods = cutreeDynamic(dendro=genetree, distM=dissTOM, 
                              deepSplit=2,pamRespectsDendro=F, minClusterSize=minClusterSize)
  #give modules a color as name
  moduleColors = labels2colors(dynamicMods)
  #sizeGrWindow(8,6)
  #plot dendrogram with the module colors
  plotDendroAndColors(genetree, moduleColors,
                      dendroLabels=F, hang=0.03,
                      addGuide=T, guideHang = 0.05,
                      main="Gene dendrogram and modules")
  output <- list(select.snps,connectivity,adjMat,dissTOM,genetree,dynamicMods,moduleColors,sft$powerEstimate)
  names(output) <- c("SNPs","connectivity","adjMat","dissTom","genetree","modules","modulecolors","power.estimate")
  return(output)
}
