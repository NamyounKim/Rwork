library(ggiraph)
library(ggiraphExtra)
require(plyr)
#'The radar coordinate system is a modification of polar coordinate system, commly used for radar chart
#'
#'@param theta variable to map angle to (x or y)
#'@param start offset of starting point from 12 o'clock in radians
#'@importFrom ggplot2 ggproto
#'@param direction 1, clockwise; -1, counterclockwise
coord_radar <- function (theta = "x", start = 0, direction = 1)
{
  theta <- match.arg(theta, c("x", "y"))
  r <- if (theta == "x")
    "y"
  else "x"
  ggproto("CoordRadar", ggplot2::CoordPolar, theta = theta, r = r, start = start,
          direction = sign(direction),
          is_linear = function(coord) TRUE)
}

#'Rescale all numeric variables of a data.frame except grouping variable
#'
#'@param data A data.frame
#'@param groupvar A column name used as a grouping variable
#'@importFrom scales rescale
#'
#'@export
#'@return A rescaled data.frame
rescale_df=function(data,groupvar=NULL){
  if(is.null(groupvar)) df=data
  else df=data[,-which(names(data) %in% groupvar)]
  
  select=sapply(df,is.numeric)
  df[select]=lapply(df[select], scales::rescale)
  if(!is.null(groupvar)) {
    df=cbind(df,data[groupvar])
    #colnames(df)[length(df)]=groupvar
  }
  df
}


#'Draw a radar chart
#'
#'@param data A data.frame
#'@param mapping Set of aesthetic mappings created by aes or aes_.
#'@param rescale A logical value. If TRUE, all continuous variables in the data.frame are rescaled.
#'@param legend.position Legend position. One of c("top","bottom","left","right","none")
#'@param colour A name of color to be assigned as a color variable
#'@param alpha  Any numbers from 0 (transparent) to 1 (opaque)
#'@param size  Point size
#'@param ylim A numeric vector of length 2, giving the y coordinates ranges.
#'@param interactive A logical value. If TRUE, an interactive plot will be returned
#'@param ... other arguments passed on to geom_point
#'@importFrom reshape2 melt
#'@importFrom plyr ddply summarize
#'@importFrom ggiraph geom_polygon_interactive geom_point_interactive
#'@importFrom ggplot2 expand_limits theme xlab ylab
#'@return An interactive radar plot
#'@export
#'@examples
#'require(ggplot2)
#'require(ggiraph)
#'require(plyr)
#'require(reshape2)
#'ggRadar(data=iris,aes(group=Species))
#'ggRadar(data=mtcars,interactive=TRUE)
#'ggRadar(data=mtcars,aes(colour=am),interactive=TRUE)
ggRadar2=function(data,mapping=NULL,
                 rescale=TRUE,
                 legend.position="top",
                 colour="red",
                 alpha=0.3,
                 size=3,
                 ylim=NULL,
                 interactive=FALSE,...){
  
  # mapping=aes(fill=am)
  # mapping=NULL
  
  (groupname=setdiff(names(mapping),c("x","y")))
  
  if(is.null(groupname)) {
    groupvar<-NULL
  } else {
    (groupvar=paste(mapping[groupname]))
  }
  if(length(groupvar)>1) warning("Only one grouping variable is allowed")
  data=num2factorDf(data,groupvar)
  
  (select=sapply(data,is.numeric))
  
  if(length(paste0(mapping[["x"]]))==0) {
    xvars=colnames(data)[select]
  } else {
    xvars=paste0(mapping[["x"]])
    if(length(xvars)>1) xvars<-xvars[-1]
    if(length(xvars)<3) warning("At least three variables are required")
  }
  
  (xvars=setdiff(xvars,groupvar))
  
  
  if(rescale) data=rescale_df(data,groupvar)
  data
  if(is.null(groupvar)) {
    data$id=1
    
    longdf=reshape2::melt(data,id.vars="id",measure.vars=xvars)
  } else{
    longdf=reshape2::melt(data,id.vars=groupvar,measure.vars=xvars)
  }
  #summary(longdf)
  
  temp=paste0("ddply(longdf,c(groupvar,'variable'),summarize,mean=mean(value,na.rm=TRUE))")
  df=eval(parse(text=temp))
  
  colnames(df)[length(df)]="value"
  
  if(is.null(groupvar)){
    df$id2="all"
    df$id=1:nrow(df)
    df$tooltip=paste0(df$variable,"=",round(df$value,1))
    df$tooltip2=paste0("all")
    #str(df)
    p<-ggplot(data=df,aes_string(x="variable",y="value",group=1))+
      geom_polygon_interactive(aes_string(tooltip="tooltip2"),colour=colour,fill=colour,alpha=alpha)+
      geom_point_interactive(aes_string(data_id="id",tooltip="tooltip"),colour=colour,size=size,...)
  } else{
    df$id2=df[[groupvar]]
    df$id=1:nrow(df)
    df$tooltip=paste0(groupvar,"=",df[[groupvar]],"<br>",df$variable,"=",round(df$value,1))
    df$tooltip2=paste0(groupvar,"=",df[[groupvar]])
    #str(df)
    p<-ggplot(data=df,aes_string(x="variable",y="value",colour=groupvar,fill=groupvar,group=groupvar))+
      geom_polygon_interactive(aes_string(tooltip="tooltip2"),alpha=alpha)+
      geom_point_interactive(aes_string(data_id="id",tooltip="tooltip"),size=size,...)
    
  }
  p
  p<- p+ xlab("")+ylab("")+theme(legend.position=legend.position, axis.text=element_text(size=12,face="bold", family = "NaumGothic"), legend.text=element_text(size=12, face="bold"))
  
  p<-p+coord_radar()
  
  if(!is.null(ylim)) p<-p+expand_limits(y=ylim)
  
  if(interactive){
    tooltip_css <- "background-color:white;font-style:italic;padding:10px;border-radius:10px 20px 10px 20px;"
    #hover_css="fill-opacity=.3;cursor:pointer;stroke:gold;"
    hover_css="r:4px;cursor:pointer;stroke-width:6px;"
    selected_css = "fill:#FF3333;stroke:black;"
    p<-ggiraph(code=print(p),tooltip_extra_css=tooltip_css,tooltip_opacity=.75,
               zoom_max=10,hover_css=hover_css,selected_css=selected_css)
  }
  p
}