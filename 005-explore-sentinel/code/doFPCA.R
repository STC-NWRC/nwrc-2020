
doFPCA <- function(
    DF.input            = NULL,
    target.variable     = NULL,
    beam.swath          = NULL,
    year                = NULL,
    week.indices        = NULL,
    spline.grid         = NULL,
    n.order             = NULL,
    n.basis             = NULL,
    smoothing.parameter = NULL,
    n.harmonics         = NULL,
    FILE.output.RData   = paste0("tmp-",beam.swath,"-",year,"-FPC-",target.variable,".RData"),
    FILE.output.csv     = paste0("tmp-",beam.swath,"-",year,"-FPC-",target.variable,".csv"  )
    ) {

    this.function.name <- "doFPCA";
    cat(paste0("\n",paste(rep("#",50),collapse=""),"\n"));
    cat(paste0("starting: ",this.function.name,"()\n"));

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    if (file.exists(FILE.output.RData)) {
        cat(paste0("\nloading file: ",FILE.output.RData,"\n"));
        DF.output <- base::readRDS(file = FILE.output.RData);
        cat(paste0("\nexiting: ",this.function.name,"()"));
        cat(paste0("\n",paste(rep("#",50),collapse=""),"\n"));
        return( DF.output );
        }

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    require(dplyr);
    require(tidyr);
    require(fda);

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    cat("\nstr(DF.input) -- doFPCA()\n");
    print( str(DF.input) );

    DF.temp <- DF.input[,c("X_Y","type","date",target.variable)];
    colnames(DF.temp) <- gsub(
        x           = colnames(DF.temp),
        pattern     = target.variable,
        replacement = "target_variable"
        );

    DF.temp <- DF.temp %>%
        tidyr::spread(key = date, value = target_variable);

    DF.temp <- as.data.frame(DF.temp);
    rownames(DF.temp) <- DF.temp[,"X_Y"];

    DF.temp <- DF.temp[0 == rowSums(is.na(DF.temp)),];

    cat("\nstr(DF.temp) -- doFPCA()\n");
    print( str(DF.temp) );

    cat("\nsummary(DF.temp) -- doFPCA()\n");
    print( summary(DF.temp) );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    date.colnames <- as.Date(grep(
        x       = colnames(DF.temp),
        pattern = "[0-9]+{4}\\-[0-9]+{2}\\-[0-9]+{2}",
        value = TRUE
        ));

    new.year.day <- as.Date(paste0(format(date.colnames[1],"%Y"),"-01-01"));

    DF.dates <- data.frame(
        date             = date.colnames,
        date_char        = as.character(date.colnames),
        date_index       = as.integer(date.colnames) - as.integer(new.year.day),
        stringsAsFactors = FALSE
        );

    cat("\nstr(DF.dates)\n");
    print( str(DF.dates)    );

    cat("\nDF.dates\n");
    print( DF.dates    );

    cat("\nstr(DF.dates[,'date_char'])\n");
    print( str(DF.dates[,'date_char'])   );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    t.DF.temp <- t(DF.temp[,DF.dates[,"date_char"]]);
    cat("\nstr(t.DF.temp)\n");
    print( str(t.DF.temp)   );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    # create basis functions with respect to which
    # FPCA computations will be carried out
    week.basis <- fda::create.bspline.basis(
        rangeval    = range(DF.dates[,"date_index"]),
        norder      = n.order,
        nbasis      = n.basis,
        dropind     = NULL,
        quadvals    = NULL,
        values      = NULL,
        basisvalues = NULL,
        names       = "bspl"
        );

    cat("\nstr(week.basis):\n");
    print( str(week.basis)    );

    # create associated functional data
    # parameter object for the basis functions
    # created above
    week.fdParObj <- fda::fdPar(
        fdobj  = week.basis,
        Lfdobj = NULL,
        lambda = smoothing.parameter,
        penmat = NULL
        );

    cat("\nstr(week.fdParObj):\n");
    print( str(week.fdParObj)    );

    # express NDVI data as linear combinations
    # of the basis functions created above
    NDVI.fd <- fda::smooth.basis(
        argvals      = DF.dates[,"date_index"],
        y            = t.DF.temp,
        fdParobj     = week.fdParObj,
        wtvec        = NULL,
        fdnames      = NULL,
        covariates   = NULL,
        method       = "chol",
        dfscale      = 1,
        returnMatrix = FALSE
        );

    cat("\nstr(NDVI.fd):\n");
    print( str(NDVI.fd)    );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    spline.grid <- seq(
        min(DF.dates[,"date_index"]),
        max(DF.dates[,"date_index"]),
        0.1
        );

    visualize.bslpine.fit(
        week.indices     = DF.dates[,"date_index"],
        spline.grid      = spline.grid,
        t.DF.time.series = t.DF.temp,
        time.series.fd   = NDVI.fd,
        prefix           = paste0(beam.swath,"-",year,"-",target.variable)
        );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    return.value.tryCatch <- tryCatch(
        expr = {
            results.pca.fd <- fda::pca.fd(
                fdobj = NDVI.fd[["fd"]],
                nharm = n.harmonics
                );
            },
        error = function(e) {
            my.message <- paste0("Error: fda::pca.fd(), ",beam.swath,", ",year,", ",target.variable);
            message("\n");
            message(my.message);
            message(e);
            message("\n");
            return( -1 );
            }
        );

    if ( "pca.fd" != class(return.value.tryCatch) ) {
        if ( 0 > return.value.tryCatch ) { return(NULL) }
        }

    cat("\nstr(results.pca.fd):\n");
    print( str(results.pca.fd)    );

    cat("\nresults.pca.fd[['values']]:\n");
    print( results.pca.fd[['values']]    );

    cat("\nresults.pca.fd[['values']] / sum(results.pca.fd[['values']]):\n");
    print( results.pca.fd[['values']] / sum(results.pca.fd[['values']])   );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    return.value.tryCatch <- tryCatch(
        expr = {
            n.plots    <- min(5,n.harmonics);
            PNG.output <- paste0("tmp-",beam.swath,"-",year,"-FPCA-",target.variable,".png");
            png(filename = PNG.output, height = 4 * n.plots, width = 12, units = "in", res = 300);
            par(mfrow=c(n.plots,1));
            plot.pca.fd(x = results.pca.fd, harm = 1:n.plots);
            dev.off();
            },
	error = function(e) {
            my.message <- paste0("Error: fda::plot.pca.fd(), ",beam.swath,", ",year,", ",target.variable);
            message("\n");
            message(my.message);
            message(e);
            message("\n");
	    message("\nstr(results.pca.fd)\n");
	    message(   str(results.pca.fd)   );
            return( -1 );
	    }
        );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    visualize.fpca.fit(
        week.indices     = DF.dates[,"date_index"],
        spline.grid      = spline.grid,
        t.DF.time.series = t.DF.temp,
        time.series.fd   = NDVI.fd,
        results.pca.fd   = results.pca.fd,
        prefix           = paste0(beam.swath,"-",year,"-",target.variable)
        );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    ### Recalculating the FPCA scores.
    ### It is necessary to know how to do this
    ### in order to incorporate FPCA-based feature
    ### extraction into the preprocessing component
    ### of a model training pipeline.

    reconstruct.fpca.scores(
        week.indices   = DF.dates[,"date_index"],
    	time.series.fd = NDVI.fd,
        week.fdParObj  = week.fdParObj,
        results.pca.fd = results.pca.fd
        );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    fpc.scores <- results.pca.fd[["scores"]];
    colnames(fpc.scores) <- paste0("fpc_",seq(1,ncol(fpc.scores)));

    cat("\nstr(DF.temp)\n");
    print( str(DF.temp)   );

    cat("\nstr(fpc.scores)\n");
    print( str(fpc.scores)   );

    DF.output <- cbind(DF.temp,fpc.scores);

    cat("\nstr(DF.output)\n");
    print( str(DF.output)   );

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    cat(paste0("\nsaving to file: ",FILE.output.RData,"\n"));
    base::saveRDS(object = DF.output, file = FILE.output.RData);

    if ( !file.exists(FILE.output.csv) ) {
        cat(paste0("\nwriting file: ",FILE.output.csv,"\n"));
        write.csv(
            file      = FILE.output.csv,
            x         = DF.output,
            row.names = FALSE
            );
        }

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    temp.list <- list(
        list(x.var = "fpc_1", y.var = "fpc_2"),
        list(x.var = "fpc_1", y.var = "fpc_3"),
        list(x.var = "fpc_2", y.var = "fpc_3"),
        list(x.var = "fpc_1", y.var = "fpc_4"),
        list(x.var = "fpc_2", y.var = "fpc_4"),
        list(x.var = "fpc_3", y.var = "fpc_4")
        );

    for ( i in 1:length(temp.list) ) {
        x.var      <- temp.list[[i]][["x.var"]];
        y.var      <- temp.list[[i]][["y.var"]];
        PNG.output <- paste0('tmp-',beam.swath,'-',year,'-FPCA-scatter-',target.variable,'-',x.var,'-',y.var,'.png');
        doFPCA_scatter(
            DF.input   = DF.output,
            beam.swath = beam.swath,
            year       = year,
            x.var      = x.var,
            y.var      = y.var,
            title      = NULL,
            subtitle   = paste0(beam.swath,', ',year,', ',target.variable),
            PNG.output = PNG.output
            );
        }

    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ###
    cat(paste0("\nexiting: ",this.function.name,"()"));
    cat(paste0("\n",paste(rep("#",50),collapse=""),"\n"));
    return( DF.output );

    }

##################################################
doFPCA_scatter <- function(
    DF.input   = NULL,
    beam.swath = NULL,
    year       = NULL,
    x.var      = NULL,
    y.var      = NULL,
    title      = NULL,
    subtitle   = NULL,
    PNG.output = 'tmp-FPCA-scatter.png'
    ) {

    require(ggplot2);

    DF.temp <- DF.input[,c("type",x.var,y.var)];

    colnames(DF.temp) <- gsub(
        x           = colnames(DF.temp),
        pattern     = x.var,
        replacement = "x_var"
        );

    colnames(DF.temp) <- gsub(
        x           = colnames(DF.temp),
        pattern     = y.var,
        replacement = "y_var"
        );

    my.ggplot <- initializePlot(
        title    = title,
        subtitle = subtitle
        );

    my.ggplot <- my.ggplot + xlab(label = x.var);
    my.ggplot <- my.ggplot + ylab(label = y.var);

    my.ggplot <- my.ggplot + geom_point(
        data    = DF.temp,
        mapping = aes(x = x_var, y = y_var, colour = type),
        alpha   = 0.3
        );

    ggsave(
        file   = PNG.output,
        plot   = my.ggplot,
        dpi    = 300,
        height =   8,
        width  =  10,
        units  = 'in'
        );

    return( NULL );

    }

