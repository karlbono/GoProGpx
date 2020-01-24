//
//  GPMF_create_GPS_data.h
//  gopro2gpx
//
//  Created by Karl Bono on 19/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

#ifndef GPMF_create_GPS_data_h
#define GPMF_create_GPS_data_h


#endif /* GPMF_create_GPS_data_h */

typedef struct GPS_data {
    double lon;
    double lat;
    double ele;
    double time;
} GPS_data;

GPS_data* Create_GPS_data(char *fileName, int*numberOfElements);
