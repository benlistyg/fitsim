#20200820

#Libraries
library(mirt)
library(dplyr)
library(drake)
library(furrr)
library(doParallel)

#Cleaning env
rm(list = ls())

# For loading bar on sim and parallelizing
future::plan(multiprocess)
# Using ALL cores
cl <- makeCluster(detectCores())
# Activating all cores
registerDoParallel(cl)

# For when you're re-running it on Drake
clean(plan, destroy = T)

# Reps per sim condition
n_reps <- 50

# For reproducing results
set.seed(04101994)

# Simulation function
fitsim <- function(correct_model, 
                   incorrect_model, 
                   n_factors, 
                   n_items,
                   misspecification, 
                   n_people, 
                   response_options, 
                   item_type,
                   n_,
                   ...){
    if(n_factors == 2){
        
        if(item_type == 'gpcm'){
            
            sigma <- diag(2)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            
            a[1:(n_items/2), 1] <- rlnorm(n_items/2, 0.2, 0.2)
            a[((n_items/2)+1):n_items, 2] <- rlnorm(n_items/2, 0.2, 0.2)
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            diffs <- -(diffs - rowMeans(diffs))
            d <- matrix(diffs + rnorm(n_items), ncol = (response_options-1))
            d <- cbind(matrix(rep(0, n_items)),d)
            
            simulated_data <- simdata(a = a, d = d, N = n_people, itemtype = item_type, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     quadpts=40,
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       quadpts=40,
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            return(cbind(M2_output,
                         n_items,
                         response_options,
                         n_people,
                         correct_model,
                         incorrect_model,
                         n_factors,
                         misspecification))     
        }
        
        if(item_type == 'nominal'){
            
            sigma <- diag(2)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            
            a[1:(n_items/2), 1] <- rlnorm(n_items/2, 0.2, 0.2)
            a[((n_items/2)+1):n_items, 2] <- rlnorm(n_items/2, 0.2, 0.2)
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            diffs <- -(diffs - rowMeans(diffs))
            d <- matrix(diffs + rnorm(n_items), ncol = (response_options-1))
            d <- cbind(matrix(rep(0, n_items)),d)
            
            nominal <- cbind(
                rep(0,n_items),
                matrix(nrow = n_items, 
                       ncol = response_options - 2, 
                       data = rlnorm(n = n_items*(response_options-2), 
                                     meanlog = 1, 
                                     sdlog = 1/(response_options-1))),
                rep(response_options-1, n_items)
            )
            
            simulated_data <- simdata(a = a, d = d, N = n_people, itemtype = item_type, nominal = nominal, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     quadpts=40,
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       quadpts=40,
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            cbind(M2_output,
                  n_items,
                  response_options,
                  n_people,
                  correct_model,
                  incorrect_model,
                  n_factors,
                  misspecification)   
        }
        
        if(item_type == 'graded'){
            
            sigma <- diag(2)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            
            a[1:(n_items/2), 1] <- runif(n_items/2, 0.8, 1.0)
            a[((n_items/2)+1):n_items, 2] <- runif(n_items/2, 0.8, 1.0)
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            diffs <- -(diffs - rowMeans(diffs))
            d <- diffs + rnorm(n_items)
            
            simulated_data <- simdata(a = a, d = d, N = n_people, itemtype = item_type, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            return(cbind(M2_output,
                         n_items,
                         response_options,
                         n_people,
                         correct_model,
                         incorrect_model,
                         n_factors,
                         misspecification))    
        }
        
        if(item_type == 'ggum'){
            
            sigma <- diag(2)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            a[1:(n_items/2), 1] <- rlnorm(n_items/2, 0.2, 0.2)
            a[((n_items/2)+1):n_items, 2] <- rlnorm(n_items/2, 0.2, 0.2)
            
            b <- matrix(0, ncol = n_factors, nrow = n_items)
            b[1:(n_items/2), 1] <- rnorm(n_items/2)
            b[((n_items/2)+1):n_items, 2] <- rnorm(n_items/2)
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            t_parameters <- -(diffs - rowMeans(diffs))
            
            simulated_data <- simdata(a = a, d = b, t = t_parameters, N = n_people, itemtype = item_type, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     quadpts=40,
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       quadpts=40,
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            return(cbind(M2_output,
                         n_items,
                         response_options,
                         n_people,
                         correct_model,
                         incorrect_model,
                         n_factors,
                         misspecification)) 
        }
    }
    
    if(n_factors == 3){
        
        if(item_type == 'gpcm'){
            
            sigma <- diag(n_factors)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            
            a[1:round((n_items/n_factors)), 1] <- rlnorm(length(1:round((n_items/n_factors))), 0.2, 0.2)
            a[(round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1), 2] <- rlnorm(length((round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1)), 0.2, 0.2)
            a[((2*(round((n_items/n_factors)))+1)+1):n_items, 3] <- rlnorm(length(((2*(round((n_items/n_factors)))+1)+1):n_items), 0.2, 0.2)
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            diffs <- -(diffs - rowMeans(diffs))
            d <- matrix(diffs + rnorm(n_items), ncol = (response_options-1))
            d <- cbind(matrix(rep(0, n_items)),d)
            
            simulated_data <- simdata(a = a, d = d, N = n_people, itemtype = item_type, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     quadpts=40,
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       quadpts=40,
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            return(cbind(M2_output,
                         n_items,
                         response_options,
                         n_people,
                         correct_model,
                         incorrect_model,
                         n_factors,
                         misspecification))     
        }
        
        if(item_type == 'graded'){
            
            sigma <- diag(2)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            
            a[1:round((n_items/n_factors)), 1] <- runif(length(1:round((n_items/n_factors))), 0.8, 1.0)
            a[(round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1), 2] <- runif(length((round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1)), 0.8, 1.0)
            a[((2*(round((n_items/n_factors)))+1)+1):n_items, 3] <- runif(length(((2*(round((n_items/n_factors)))+1)+1):n_items), 0.8, 1.0)
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            diffs <- -(diffs - rowMeans(diffs))
            d <- diffs + rnorm(n_items)
            
            simulated_data <- simdata(a = a, d = d, N = n_people, itemtype = item_type, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            return(cbind(M2_output,
                         n_items,
                         response_options,
                         n_people,
                         correct_model,
                         incorrect_model,
                         n_factors,
                         misspecification))    
        }
        
        if(item_type == 'ggum'){
            
            sigma <- diag(2)
            sigma[upper.tri(sigma)] <- 0.5
            sigma[lower.tri(sigma)] <- 0.5
            
            a <- matrix(0, ncol = n_factors, nrow = n_items)
            
            a[1:round((n_items/n_factors)), 1] <- rlnorm(length(1:round((n_items/n_factors))), 0.2, 0.2)
            a[(round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1), 2] <- rlnorm(length((round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1)), 0.2, 0.2)
            a[((2*(round((n_items/n_factors)))+1)+1):n_items, 3] <- rlnorm(length(((2*(round((n_items/n_factors)))+1)+1):n_items), 0.2, 0.2)
            
            b <- matrix(0, ncol = n_factors, nrow = n_items)
            
            b[1:round((n_items/n_factors)), 1] <- rnorm(length(1:round((n_items/n_factors))))
            b[(round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1), 2] <- rnorm(length((round((n_items/n_factors))+1):(2*(round((n_items/n_factors)))+1)))
            b[((2*(round((n_items/n_factors)))+1)+1):n_items, 3] <- rnorm(length(((2*(round((n_items/n_factors)))+1)+1):n_items))
            
            diffs <- t(apply(matrix(runif(n_items*(response_options-1), .3, 1), n_items), 1, cumsum))
            t_parameters <- -(diffs - rowMeans(diffs))
            
            simulated_data <- simdata(a = a, d = b, t = t_parameters, N = n_people, itemtype = item_type, sigma = sigma)
            
            correctly_fitted <- mirt(data = simulated_data,
                                     model = correct_model,
                                     itemtype = item_type,
                                     technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                     quadpts=40,
                                     optimizer="nlminb", 
                                     control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                     method = 'QMCEM',
                                     TOL=1e-03,)
            
            incorrectly_fitted <- mirt(data = simulated_data,
                                       model = incorrect_model,
                                       itemtype = item_type,
                                       technical=list(theta_lim=c(-3,3), NCYCLES = 10000),
                                       quadpts=40,
                                       optimizer="nlminb", 
                                       control=list(rel.tol=1e-10,abs.tol=1e-20,iter.max=20), 
                                       method = 'QMCEM',
                                       TOL=1e-03,)
            
            M2_output <- rbind(
                
                M2(correctly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Correct'),
                
                M2(incorrectly_fitted, 
                   QMC = T, 
                   quadpts = 15000) %>%
                    mutate(Model = 'Incorrect')
                
            )
            
            return(cbind(M2_output,
                         n_items,
                         response_options,
                         n_people,
                         correct_model,
                         incorrect_model,
                         n_factors,
                         misspecification)) 
        }
    }
}

# Generating drake plan
plan <- drake_plan(
    model_list = read.csv('https://raw.githubusercontent.com/benlistyg/fitsim/master/models.csv') %>% 
        mutate(correct_model = gsub(pattern = '\\n',
                                    replacement = '\n',
                                    correct_model,
                                    fixed = T),
               incorrect_model = gsub(pattern = '\\n',
                                      replacement = '\n',
                                      incorrect_model,
                                      fixed = T)),
    # Sim conditions, modify the parts in the expand.grid() section
    # to change study conditions
    simulation_conditions = expand.grid(
        n_people = c(150,250,500,750,1000),
        response_options = c(3,4,5),
        item_type = c("graded","gpcm","ggum","nominal"), 
        stringsAsFactors = F) %>% 
        tidyr::crossing(model_list, .) %>% 
        filter(n_factors == 2,
               item_type %in% c('nominal')) %>% #Only doing 2D models
        arrange(n_items) %>% 
        slice(rep(row_number(), n_reps)) %>% 
        mutate(n_ = 1:nrow(.))
)

make(plan)

loadd()

begin_ <- Sys.time()

simulation_results <- simulation_conditions[1:300,] %>%
    split(.$n_) %>%
    future_map(~ plyr::mdply(.data = ., 
                             .fun = fitsim, 
                             .inform = T),
               .progress =T) %>% 
    future_map_dfr(~ as.data.frame(.))

end_ <- Sys.time() - begin_

end_

stopCluster(cl)
