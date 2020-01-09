# blackalert

```USAGE:       $strName -r [pre|post|batch] -e [live|test] [-d directory for batch]   
                                                                                    
  -r pre     Run the PRE-transcoding workflow for on raw rips                       
             so that they have standardised stream titles, forced subs,             
             correct default audio in addition to saved JSON, mkvpropedits          
             and TSVs.                                                              
             MKVs are also renamed correctly using FileBot to conform with          
             Plex's naming for movies and TV shows.                                 
             Most importantly, the individual other-transcode command per           
             MKV is generated and then concatenated into one commands.bat           
             file to be run on Windows.                                             
                                                                                    
  -r post    Run the POST-transcoding workflow on raw, JSON, mkvpropedit,           
             CVS and transcoded content. This content is moved to its final         
             locations within the Media (raw) and Plex NAS folders.                 
                                                                                    
  -r batch   Takes the mkv raw content provided by -d and processes it automatically
                                                                                    
  -e live    Location/path selections for the real content stored on the NAS        
             and correctly archived in addition to being made available             
             for Plex                                                               
  -e test    Location/path selections for the content stored locally as part        
             of testing on both Mac and Windows                                     
  -d <path>  Path to the parent directory of MKVs for batch processing  ```
  
