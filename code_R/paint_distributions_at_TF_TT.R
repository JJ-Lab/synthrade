library("grid")
library("gridExtra")
library("igraph")
library("ggplot2")
source("aux_functions_matrix.R")
source("parse_command_line_args.R")


calc_accum <- function(datosinput)
{
  datosacc <- datosinput[order(datosinput$weight),]
  datosacc$ac_degree <- 0
  datosacc$ac_strength <- 0
  datosacc$ac_degree[1] <- datosacc$degree[1]
  datosacc$ac_strength[1] <- datosacc$weight[1]
  for (i in 2:nrow(datosacc)){
    datosacc$ac_degree[i] <- datosacc$ac_degree[i-1]+datosacc$degree[i]
    datosacc$ac_strength[i] <- datosacc$ac_strength[i-1]+datosacc$weight[i]
  }
  datosacc$ac_strength <- datosacc$ac_strength/max(datosacc$ac_strength)
  return(datosacc)
}

gen_links_strength_distribution <- function(red,series, colors, seq_breaks = c(1,5,10,20,50,100), empirical = FALSE)
{
  gen_ls_data_frame <- function(input_matrix,tipo,tamanyo,nalpha,serie,titlestr)
  {
    
    # Remove all zeroes columns and rows
    dfint <- as.data.frame(input_matrix)
    write.csv(dfint,"dfcab.csv")
    dr <- lread_network("dfcab.csv", guild_astr = "Exporter", guild_bstr = "Importer", directory="")
    grafo <- as.undirected(dr[["graph"]])
    ddegree <- igraph::degree(grafo,mode = c("out"), loops = TRUE, normalized = FALSE)
    dfdeg <- data.frame("degree" = as.numeric(ddegree))
    dfdeg$type <- "Exporter"
    dfdeg$tamanyo <- tamanyo
    dfdeg$nalpha <- nalpha
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
    
    dfaccum <- calc_accum(dfdeg) 
    #ddeg_exporter <- dfdeg[dfdeg$type == "Exporter",]
    ddeg_exporter <- dfaccum[dfaccum$type == "Exporter",]
    
    degree <- ddeg_exporter$degree
    weight <- ddeg_exporter$weight
    ac_strength <- ddeg_exporter$ac_strength
    ac_degree <- ddeg_exporter$ac_degree
    datosplot <- data.frame("degree" = degree, "strength" = weight, 
                            "ac_strength" = ac_strength, "ac_degree" = ac_degree)
    dpexp <- datosplot
    
    mod <- lm(datosplot$strength ~ datosplot$degree)
    etmodel <- sprintf("log10 s = %.4f log10 d %.4f     Adj. R^2 = %0.3f",
                       as.numeric(mod[[1]][2]),as.numeric(mod[[1]][1]),summary(mod)$adj.r.squared)
    exptf <- ggplot(datosplot,aes(x=degree,y=strength))+geom_point(color="blue",alpha=0.5)+scale_x_log10()+scale_y_log10()+
      ggtitle(paste0("Exporters at ",titlestr))+ 
      geom_smooth(method = "lm", se = FALSE, show.legend = TRUE,color="grey50",linetype = "dashed")+
      geom_text(x=1, y=0,label=etmodel, size = 5)+xlab("Degree")+ylab("Normalized strength")+
      theme_bw() +  theme(plot.title = element_text(hjust = 0.5, size = 18),
                          axis.title.x = element_text(color="grey30", size = 15, face="bold"),
                          axis.title.y = element_text(color="grey30", size= 15, face="bold"),
                          legend.title=element_blank(),
                          legend.position = "top",
                          legend.text=element_text(size=10),
                          panel.grid.minor = element_blank(),
                          axis.text.x = element_text(face="bold", color="grey30", size=14),
                          axis.text.y = element_text(face="bold", color="grey30", size=14)
      )

    dfaccum <- calc_accum(dfdeg) 
    #ddeg_importer <- dfdeg[dfdeg$type == "Importer",]
    ddeg_importer <- dfaccum[dfaccum$type == "Importer",]
    degree <- ddeg_importer$degree
    weight <- ddeg_importer$weight
    ac_strength <- ddeg_importer$ac_strength
    ac_degree <- ddeg_importer$ac_degree
    datosplot <- data.frame("degree" = degree, "strength" = weight, 
                            "ac_strength" = ac_strength, "ac_degree" = ac_degree)
    dpimp <- datosplot
    mod <- lm(datosplot$strength ~ datosplot$degree)
    etmodel <- sprintf("log10 s = %.4f log10 d %.4f     Adj. R^2 = %0.3f",as.numeric(mod[[1]][2]),as.numeric(mod[[1]][1]),summary(mod)$adj.r.squared)
    
    imptf <- ggplot(datosplot,aes(x=degree,y=strength))+geom_point(colour="red",alpha=0.5)+scale_x_log10()+scale_y_log10()+
         ggtitle(paste0("Importers at ",titlestr))+
         geom_smooth(method = "lm", se = FALSE, show.legend = TRUE,color="grey50",linetype = "dashed")+
         geom_text(x=1, y=max(log10(datosplot$strength)),label=etmodel, size = 5)+xlab("Degree")+ylab("Normalized strength")+
      theme_bw() +  theme(plot.title = element_text(hjust = 0.5, size = 18),
                          axis.title.x = element_text(color="grey30", size = 15, face="bold"),
                          axis.title.y = element_text(color="grey30", size= 15, face="bold"),
                          legend.title=element_blank(),
                          legend.position = "top",
                          legend.text=element_text(size=10),
                          panel.grid.minor = element_blank(),
                          axis.text.x = element_text(face="bold", color="grey30", size=14),
                          axis.text.y = element_text(face="bold", color="grey30", size=14)
      )


    calc_values <- list("imptf" = imptf, "exptf" = exptf, "data_exp" = dpexp, "data_imp" = dpimp)
    return(calc_values)
  }
  
  experiment <- 1
  
  if (!empirical)
  {
    dred <- gsub(TFstring,"",red)
    subdir <- "TFMatrix/"
    ficheros <- Sys.glob(paste0("../results/",subdir,red,"_W_",experiment,".txt"))
    for (j in ficheros){
      sim_matrix <- read.table(j,sep="\t")
      plots_TF <- gen_ls_data_frame(sim_matrix,"Simulated",0.5,0.02,series,"TF")
    }
    subdir <- ""
    ficheros <- Sys.glob(gsub("TF_","",paste0("../results/",subdir,red,"_W_1",".txt")))
    for (j in ficheros){
      sim_matrix <- read.table(j,sep="\t")
      plots_final <- gen_ls_data_frame(sim_matrix,"Simulated",0.5,0.02,series,"TT")
    }
  }
  
  else
  {
    dred <- gsub(TFstring,"",red)
    subdir <- "data/"
    ficheros <- Sys.glob(paste0("../",subdir,dred,".txt"))
    for (j in ficheros){
      sim_matrix <- read.table(j,sep="\t")
      plots_final <- gen_ls_data_frame(sim_matrix,"Empirical",0.5,0.02,series,"TT")
      plots_TF <- plots_final
    }

  }
  
  calc_values <- list("plots_TF" = plots_TF, "plots_final" = plots_final)
  return(calc_values)

}

plot_sq_fit <- function(datosplot,titlestr="",dcol="red")
{
  
  datatrf <- datosplot
  datatrf$log10_degree <- log10(datosplot$degree)^2
  datatrf$log10_strength <- log10(datosplot$strength)
  mod <- lm(datatrf$log10_strength ~ datatrf$log10_degree)
  minx <- min(sqrt(datatrf$log10_degree))
  maxx <- round(max(sqrt(datatrf$log10_degree)))
  
  etmodel <- sprintf("log10 s = %.3f (log10 d)^2 %.3f     Adj. R^2 = %0.2f",
                     as.numeric(mod[[1]][2]),as.numeric(mod[[1]][1]),summary(mod)$adj.r.squared)
  imptf <- ggplot(datatrf,aes(x=log10_degree,y=log10_strength))+geom_point(color=dcol,alpha=0.5)+
    ggtitle(titlestr)+xlab("Degree")+ylab("Normalized strength")+
    scale_x_continuous(breaks=c(0,1,4),labels=c(1,10,100))+
    scale_y_continuous(breaks=c(0,-2,-4),labels=c("1","1e-02","1e-04"))+
    geom_smooth(method = "lm", se = FALSE, show.legend = TRUE,color="grey50",linetype = "dashed")+
    geom_text(x=2, y=min(datatrf$log10_strength),label=etmodel, size = 5)+
    theme_bw() +  theme(plot.title = element_text(hjust = 0.5, size = 18),
                        axis.title.x = element_text(color="grey30", size = 15, face="bold"),
                        axis.title.y = element_text(color="grey30", size= 15, face="bold"),
                        legend.title=element_blank(),
                        legend.position = "top",
                        legend.text=element_text(size=10),
                        panel.grid.minor = element_blank(),
                        axis.text.x = element_text(face="bold", color="grey30", size=14),
                        axis.text.y = element_text(face="bold", color="grey30", size=14)
    )
  return(imptf)
}


plot_log_fit <- function(datosplot,titlestr="",dcol="red")
{
  
  datatrf <- datosplot
  datatrf$log10_acdegree <- log10(datatrf$ac_degree)
  datatrf$log10_acstrength <- log10(datatrf$ac_strength)
  # datosfit <- datatrf[(datatrf$log10_acstrength< quantile(datatrf$log10_acstrength,probs=c(0.7))) &
  #                       (datatrf$log10_acstrength> quantile(datatrf$log10_acstrength,probs=c(0.1)))  ,]
  datosfit <- datatrf[(datatrf$log10_acstrength< quantile(datatrf$log10_acstrength,probs=c(0.6))),]
  mod <- lm(datosfit$log10_acstrength ~ datosfit$log10_acdegree)
  beta <- mod[[1]][1]
  alpha <- mod[[1]][2]
  xmin <- min(datosfit$log10_acdegree)
  ymin <- alpha*xmin+beta
  xmax <- max(datosfit$log10_acdegree)
  ymax <- alpha*xmax+beta

  etmodel <- sprintf("log(Cs) = %.2f log(Cd) %.2f Adj. R^2 = %0.3f",as.numeric(mod[[1]][2]),as.numeric(mod[[1]][1]),summary(mod)$adj.r.squared)
  imptf <- ggplot(datatrf,aes(x=ac_degree,y=ac_strength))+geom_point(color=dcol,alpha=0.5)+
    ggtitle(titlestr)+xlab("Cumulative Degree")+ylab("Cumulative Normalized strength")+
    scale_x_log10()+scale_y_log10()+
    geom_text(x=quantile(datatrf$log10_acdegree,probs=c(0.02)), 
              y=min(datatrf$log10_acstrength),label=etmodel, size = 5, hjust=0)+
    geom_text(x=xmax,y=ymax,label="*")+
    geom_abline(slope = alpha, intercept = beta, color = "black", alpha = 0.5, linetype = 2) +
    theme_bw() +  theme(plot.title = element_text(hjust = 0.5, size = 18),
                        axis.title.x = element_text(color="grey30", size = 15, face="bold"),
                        axis.title.y = element_text(color="grey30", size= 15, face="bold"),
                        legend.title=element_blank(),
                        legend.position = "top",
                        legend.text=element_text(size=10),
                        panel.grid.minor = element_blank(),
                        axis.text.x = element_text(face="bold", color="grey30", size=14),
                        axis.text.y = element_text(face="bold", color="grey30", size=14)
    )
  return(imptf)
}

TFstring = "TF_"
files <- paste0(TFstring,"RedAdyCom",seq(ini_seq,end_seq))

for (orig_file in files)
{
  red <- paste0(orig_file,"_FILT")
  redorig <- gsub(TFstring,"",red)                #Empirical data
  series = "Exporter"
  year=gsub("_FILT","",strsplit(red,"RedAdyCom")[[1]][-1])
  grafs <- gen_links_strength_distribution(red,series,"blue",empirical = FALSE)
  
  data_e_TF <- grafs$plots_TF$data_exp
  data_i_TF <- grafs$plots_TF$data_imp
  
  sqe_TF <- plot_sq_fit(data_e_TF, titlestr = "Synthetic Exporters at TF", dcol="blue")
  sqi_TF <- plot_sq_fit(data_i_TF, titlestr = "Synthetic Importers at TF", dcol="red")
 
  acc_e_TF <- plot_log_fit(data_e_TF, titlestr = "Synthetic Exporters at TF", dcol="blue")
  acc_i_TF <- plot_log_fit(data_i_TF, titlestr = "Synthetic Importers at TF", dcol="red")
  
   
  data_e <- grafs$plots_final$data_exp
  data_i <- grafs$plots_final$data_imp
  
  sqe <- plot_sq_fit(data_e, titlestr = "Synthetic Exporters at TT", dcol="blue")
  sqi <- plot_sq_fit(data_i, titlestr = "Synthetic Importers at TT", dcol="red")
  
  acc_e <- plot_log_fit(data_e, titlestr = "Synthetic Exporters at TT", dcol="blue")
  acc_i <- plot_log_fit(data_i, titlestr = "Synthetic Importers at TT", dcol="red")
  
  grafsemp <-  gen_links_strength_distribution(red,series,"blue",empirical = TRUE)
  data_e_emp <- grafsemp$plots_final$data_exp
  data_i_emp <- grafsemp$plots_final$data_imp
  sqe_emp <- plot_sq_fit(data_e_emp, titlestr = "Empirical Exporters", dcol="blue")
  sqi_emp <- plot_sq_fit(data_i_emp, titlestr = "Empirical Importers", dcol="red")
  
  acc_e_emp <- plot_log_fit(data_e_emp, titlestr = "Empirical Exporters", dcol="blue")
  acc_i_emp <- plot_log_fit(data_i_emp, titlestr = "Empirical Importers", dcol="red")
  
  # dir.create("../figures/linksstrength/", showWarnings = FALSE)
  # ppi <- 300
  # png(paste0("../figures/linksstrength/LS_SYNTH_",red,".png"), width=(16*ppi), height=12*ppi, res=ppi)
  # # grid.arrange(grafs$plots_TF$imptf,grafs$plots_final$imptf, sqi, grafs$plots_TF$exptf,
  # #             grafs$plots_final$exptf,sqe,ncol=3, nrow=2)
  # grid.arrange(grafs$plots_TF$imptf,sqi, grafs$plots_TF$exptf,sqe,ncol=2, nrow=2)
  # dev.off()
  # 
  # ppi <- 300
  # png(paste0("../figures/linksstrength/LS_EMP_",red,".png"), width=(16*ppi), height=12*ppi, res=ppi)
  # grid.arrange(sqi,sqi_emp,sqe,sqe_emp,ncol=2, nrow=2)
  # dev.off()
  
  dir.create("../figures/linksstrength/", showWarnings = FALSE)
  ppi <- 300
  png(paste0("../figures/linksstrength/LS_SYNTH_",red,".png"), width=(22*ppi), height=12*ppi, res=ppi)
  grid.arrange(sqi_TF, sqi, sqi_emp, sqe_TF, sqe, sqe_emp, ncol=3, nrow=2)
  dev.off()
  
  dir.create("../figures/linksstrength/", showWarnings = FALSE)
  ppi <- 300
  png(paste0("../figures/linksstrength/LS_SYNTH_LOG_",red,".png"), width=(22*ppi), height=12*ppi, res=ppi)
  grid.arrange(acc_i_TF, acc_i, acc_i_emp, acc_e_TF, acc_e, acc_e_emp, ncol=3, nrow=2)
  dev.off()
  
  dir.create("../figures/linksstrength/", showWarnings = FALSE)
  ppi <- 300
  png(paste0("../figures/linksstrength/LS_EMP_LOG_",red,".png"), width=(14*ppi), height=6*ppi, res=ppi)
  grid.arrange(acc_i_emp, acc_e_emp, ncol=2, nrow=1)
  dev.off()
  
}