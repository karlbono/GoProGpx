//
//  main.c
//  mp4gopro2gpx
//
//  Created by Karl Bono on 08/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

#include <stdio.h>

/*! @file GPMF_demo.c
 *
 *  @brief Demo to extract GPMF from an MP4
 *
 *  @version 1.0.1
 *
 *  (C) Copyright 2017 GoPro Inc (http://gopro.com/).
 *
 *  Licensed under either:
 *  - Apache License, Version 2.0, http://www.apache.org/licenses/LICENSE-2.0
 *  - MIT license, http://opensource.org/licenses/MIT
 *  at your option.
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#include "GPMF_parser.h"
#include "GPMF_mp4reader.h"
#include "GPMF_create_GPS_data.h"


extern void PrintGPMF(GPMF_stream *ms);

GPS_data* Create_GPS_data(char *fileName, int*numberOfElements)
{
    int32_t ret = GPMF_OK;
    GPMF_stream metadata_stream, *ms = &metadata_stream;
    double metadatalength;
    uint32_t *payload = NULL; //buffer to store GPMF samples from the MP4.
    GPS_data *returnData = NULL;
    *numberOfElements = 0;
    
    size_t mp4 = OpenMP4Source(fileName, MOV_GPMF_TRAK_TYPE, MOV_GPMF_TRAK_SUBTYPE);
    metadatalength = GetDuration(mp4);
    //printf("metadata:%f\n",metadatalength);

    if (metadatalength > 0.0)
    {
        uint32_t index, payloads = GetNumberPayloads(mp4);
//        printf("found %.2fs of metadata, from %d payloads, within %s\n", metadatalength, payloads, fileName);
//        printf("payloads:%i\n",payloads);
        
        for (index = 0; index < payloads; index++)
        {
            uint32_t payloadsize = GetPayloadSize(mp4, index);
            payload = GetPayload(mp4, payload, index);
            if (payload == NULL)
                goto cleanup;
            ret = GPMF_Init(ms, payload, payloadsize);
            if (ret != GPMF_OK)
                goto cleanup;
            if (GPMF_OK == GPMF_FindNext(ms, STR2FOURCC("GPS5"), GPMF_RECURSE_LEVELS) || //GoPro Hero5/6/7 GPS
                GPMF_OK == GPMF_FindNext(ms, STR2FOURCC("GPRI"), GPMF_RECURSE_LEVELS))   //GoPro Karma GPS
            {
                uint32_t samples = GPMF_Repeat(ms);
                *numberOfElements += samples;
            }
            GPMF_ResetState(ms);
        }
        
//        printf("numberofelements = %i",*numberOfElements);
        
        if (*numberOfElements > 0) returnData = (GPS_data*)malloc(*numberOfElements*sizeof(GPS_data));
        int returnedIndex = 0;
        
        for (index = 0; index < payloads; index++)
        {
            uint32_t payloadsize = GetPayloadSize(mp4, index);
            float in = 0.0, out = 0.0; //times
            payload = GetPayload(mp4, payload, index);
            if (payload == NULL)
                goto cleanup;
            
            ret = GetPayloadTime(mp4, index, &in, &out);
            if (ret != GPMF_OK)
                goto cleanup;
            
            ret = GPMF_Init(ms, payload, payloadsize);
            if (ret != GPMF_OK)
                goto cleanup;
            
            double timeBase = 0;
            if (GPMF_OK == GPMF_FindNext(ms, STR2FOURCC("GPSU"), GPMF_RECURSE_LEVELS)) {
                void *data = GPMF_RawData(ms);
                char *U = (char *)data;
                char t[17];
                t[16] = 0;
                strncpy(t, U, 16);
                struct tm tm;
                memset(&tm, 0, sizeof(struct tm));
                strptime(t, "%y%m%d%H%M%S", &tm);
                timeBase = mktime(&tm);
                char milliseconds[6];
                milliseconds[5] = 0;
                milliseconds[0] = '0';
                strncpy(milliseconds+1, t+12, 4);
                timeBase += atof(milliseconds);
//                printf("t:%s\n",t);
//                printf("timebase:%f\n",timeBase);
//                printf("milliseconds:%s\n",milliseconds);

           }

            if (GPMF_OK == GPMF_FindNext(ms, STR2FOURCC("GPS5"), GPMF_RECURSE_LEVELS) || //GoPro Hero5/6/7 GPS
                GPMF_OK == GPMF_FindNext(ms, STR2FOURCC("GPRI"), GPMF_RECURSE_LEVELS))   //GoPro Karma GPS
            {
                //uint32_t key = GPMF_Key(ms);
                uint32_t samples = GPMF_Repeat(ms);
                uint32_t elements = GPMF_ElementsInStruct(ms);
                uint32_t buffersize = samples * elements * sizeof(double);
//                GPMF_stream find_stream;
                double *ptr, *tmpbuffer = malloc(buffersize);
//                char units[10][6] = { "" };
//                uint32_t unit_samples = 1;
                
//                printf("MP4 Payload time %.3f to %.3f seconds\n", in, out);
                
                if (tmpbuffer && samples)
                {
                    uint32_t i, j;
                    
                    GPMF_ScaledData(ms, tmpbuffer, buffersize, 0, samples, GPMF_TYPE_DOUBLE);  //Output scaled data as floats
                    
                    ptr = tmpbuffer;
                    
//                    printf("samples %i\n",samples);
//                    printf("numberofelements %i\n",*numberOfElements);
                    
                    //if (samples>0) extractedData[index] = (GPS_data*)malloc(samples*sizeof(GPS_data));
                    double timeIncrement = (out - in)/samples;
                    for (i = 0; i < samples; i++)
                    {
                        for (j = 0; j < elements; j++) {
                            if (j==0) returnData[returnedIndex].lat = *ptr;
                            if (j==1) returnData[returnedIndex].lon = *ptr;
                            if (j==2) returnData[returnedIndex].ele = *ptr;
                            //printf("%.5f%s ", *ptr, units[j%unit_samples]);
                            *ptr++;
                        }
                        returnData[returnedIndex].time = timeBase + (timeIncrement*i);
                        returnedIndex++;
                    }
                    free(tmpbuffer);
                }
            }
            GPMF_ResetState(ms);
        }
        
    cleanup:
        if (payload) FreePayload(payload); payload = NULL;
        CloseSource(mp4);
    }
    return returnData;
}
