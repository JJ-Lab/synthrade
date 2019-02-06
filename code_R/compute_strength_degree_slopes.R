#  Compute strength-degree slopes 
#  
#  Results are stored at Results/Slopes.txt

library("grid")
library("gridExtra")
library("igraph")
source("aux_functions_matrix.R")
source("parse_command_line_args.R")

ini_seq <- 1962
end_seq <- 2014

gen_links_strength_models <- function(namefile,red,series, seq_breaks = c(1,5,10,20,50,100), empirical = FALSE)
{
  
  
  gen_ls_data_frame <- function(namefile,input_matrix,tipo,serie)
  {
    
    # Remove all zeroes columns and rows
    dfint <- as.data.frame(input_matrix)
    write.csv(dfint,"dfcab.csv")
    dr <- lread_network("dfcab.csv", guild_astr = "Exporter", guild_bstr = "Importer", directory="")
    grafo <- as.undirected(dr[["graph"]])
    ddegree <- igraph::degree(grafo,mode = c("out"), loops = TRUE, normalized = FALSE)
    dfdeg <- data.frame("degree" = as.numeric(ddegree))
    dfdeg$type <- "Exporter"
    dfdeg$nodename <- names(ddegree)
    dfdeg[grepl("Importer",dfdeg$nodename),]$type <- as.character("Importer")
    dfdeg <- dfdeg[order(dfdeg$degree),]
    dfdeg$weight <- 0
    for (k in 1:nrow(dfdeg)){
      if (dfdeg$type[k] == "Importer")
      {
        indice <- as.numeric(strsplit(dfdeg$nodename[k],"Importer")[[1]][2])
        dfdeg$weight[k] <- sum(as.numeric(dr$m[indice,]))
      }
      else
      {
        indice <- as.numeric(strsplit(dfdeg$nodename[k],"Exporter")[[1]][2])
        dfdeg$weight[k] <- sum(as.numeric(dr$m[,indice]))
      }
    }
    dfdeg$weight <- dfdeg$weight /max(as.numeric(dfdeg$weight))
    
    ddeg_exporter <- dfdeg[dfdeg$type == "Exporter",]
    degree <- ddeg_exporter$degree
    weight <- ddeg_exporter$weight
    datosplot <- data.frame("degree" = degree, "strength" = weight)
    dpexp <- datosplot
    
    exp_mod <- lm(datosplot$strength ~ datosplot$degree)


    ddeg_importer <- dfdeg[dfdeg$type == "Importer",]
    degree <- ddeg_importer$degree
    weight <- ddeg_importer$weight
    datosplot <- data.frame("degree" = degree, "strength" = weight)
    dpimp <- datosplot
    imp_mod <- lm(datosplot$strength ~ datosplot$degree)
    

    calc_values <- list("exp_mod" = exp_mod, "imp_mod" = imp_mod, "data_exp" = dpexp, "data_imp" = dpimp)
    return(calc_values)
  }
  
  
  if (!empirical)
  {
    dred <- gsub(TFstring,"",red)
    subdir <- ""
    for (j in namefile){
      sim_matrix <- read.table(j,sep="\t")
      models_final <- gen_ls_data_frame(j,sim_matrix,"Simulated",series)
    }
  }
  
  else
  {
    for (j in namefile){
      sim_matrix <- read.table(j,sep="\t")
      models_final <- gen_ls_data_frame(j,sim_matrix,"Empirical",series)

    }

  }
  
  calc_values <- list( "models_final" = models_final)
  return(calc_values)

}

compute_sq_fit <- function(datosplot,titlestr="",dcol="red")
{
  datatrf <- datosplot
  datatrf$log10_degree <- log10(datosplot$degree)^2
  datatrf$log10_strength <- log10(datosplot$strength)
  mod <- lm(datatrf$log10_strength ~ datatrf$log10_degree^2)
  return(mod)
}

TFstring = "TF_"
files <- paste0(TFstring,"RedAdyCom",seq(ini_seq,end_seq))
dfslopes <- data.frame("Year"=c(),"Experiment"=c(),
                       "ExpSlopeSynth"=c(),"ExpSynthR2"=c(),"ImpSlopeSynth"=c(),"ImpSynthR2"=c(),
                        "ExpSlopeEmp"=c(),"ExpEmpR2"=c(),"ImpSlopeEmp"=c(),"ImpEmpR2"=c())

for (year in seq(ini_seq,end_seq)){
  print(paste("Year:",year))
  orig_file <- paste0("RedAdyCom",year)
  emp_file <- paste0("../data/",orig_file,"_FILT.txt")
  experiment_files <- Sys.glob(paste0("../results/",orig_file,"_FILT_W_*.txt"))
  for (name_file in experiment_files)
  {
    red <- paste0(name_file,"_FILT")
    nexper <- as.numeric(gsub(".txt","",strsplit(name_file,"_W_")[[1]][2]))
    redorig <- gsub(TFstring,"",red)                #Empirical data
    series = "Exporter"
    models_synth <- gen_links_strength_models(name_file,red,series,empirical = FALSE)
    data_e <- models_synth$models_final$data_exp
    data_i <- models_synth$models_final$data_imp
    sqe_model <- compute_sq_fit(data_e, titlestr = "Synthetic Exporters at TT", dcol="blue")
    sqi_model <- compute_sq_fit(data_i, titlestr = "Synthetic Importers at TT", dcol="red")
    if (nexper == 1){
      models_emp <-  gen_links_strength_models(emp_file,red,series,empirical = TRUE)
      data_e_emp <- models_emp$models_final$data_exp
      data_i_emp <- models_emp$models_final$data_imp
      sqe_emp_model <- compute_sq_fit(data_e_emp, titlestr = "Empirical Exporters", dcol="blue")
      sqi_emp_model <- compute_sq_fit(data_i_emp, titlestr = "Empricial Importers", dcol="red")
    }
    dfexp<- data.frame("Year"=0,"Experiment"=0,
                           "ExpSlopeSynth"=0,"ExpSynthR2"=0,"ImpSlopeSynth"=0,"ImpSynthR2"=0,
                           "ExpSlopeEmp"=0,"ExpEmpR2"=0,"ImpSlopeEmp"=0,"ImpEmpR2"=0)
    dfexp$Year = year
    dfexp$Experiment = nexper
    dfexp$ExpSlopeSynth <- as.numeric(sqe_model[[1]][2])
    dfexp$ExpSynthR2 <- summary(sqe_model)$adj.r.squared
    dfexp$ImpSlopeSynth <- as.numeric(sqi_model[[1]][2])
    dfexp$ImpSynthR2 <- summary(sqi_model)$adj.r.squared
    dfexp$ExpSlopeEmp <- as.numeric(sqe_emp_model[[1]][2])
    dfexp$ExpEmpR2 <- summary(sqe_emp_model)$adj.r.squared
    dfexp$ImpSlopeEmp <- as.numeric(sqi_emp_model[[1]][2])
    dfexp$ImpEmpR2 <- summary(sqi_emp_model)$adj.r.squared
    dfslopes <- rbind(dfslopes,dfexp)
  }
}
write.table(dfslopes,"../results/Slopes.txt",sep="\t",row.names = FALSE)