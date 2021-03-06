// PQ any k for P3 video
// *NOTE* includes tone mapping and gamma
// for P3 video
// range limites to 16 bit FULL range

import "utilities";
import "transforms-common";
import "odt-transforms-common";
import "utilities-color";
import "PQ";

const Chromaticities P3D65_PRI =
{
  { 0.68000,  0.32000},
  { 0.26500,  0.69000},
  { 0.15000,  0.06000},
  { 0.31270,  0.32900}
};

/* ----- ODT Parameters ------ */
const float OCES_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(ACES_PRI,1.0);
const Chromaticities DISPLAY_PRI = P3D65_PRI;
const float XYZ_2_DISPLAY_PRI_MAT[4][4] = XYZtoRGB(DISPLAY_PRI,1.0);
const float DISPLAY_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(DISPLAY_PRI,1.0);


// ODT parameters related to black point compensation (BPC) and encoding
const float OUT_BP = 0.0; //0.005;
const float OUT_WP_MAX_PQ = 10000.0; //speculars


const unsigned int BITDEPTH = 16;
// video range is
// Luma and R,G,B:  CV = Floor(876*D*N+64*D+0.5)
// Chroma:  CV = Floor(896*D*N+64*D+0.5)
const unsigned int CV_BLACK = 0; //64.0*64.0;
const unsigned int CV_WHITE = 65535;



void main 
(
  input varying float rIn, 
  input varying float gIn, 
  input varying float bIn, 
  output varying float rOut,
  output varying float gOut,
  output varying float bOut,
  input uniform float MAX = 1000.0,
  input uniform float FUDGE = 1.0,
  input uniform int   ALARM = 0
)
{

// 700n 1.13, 1000n 1.17
// scale factor to put image through top of tone scale
float OUT_WP_MAX = MAX;
const float RATIO = OUT_WP_MAX/OUT_WP_MAX_PQ;
const float SCALE_MAX = pow((OCES_WP_VIDEO/(OUT_WP_VIDEO))*OUT_WP_MAX/DEFAULT_YMAX_ABS,FUDGE);
const float SCALE_MAX_TEST = (OCES_WP_VIDEO/OUT_WP_VIDEO)*OUT_WP_MAX/DEFAULT_YMAX_ABS;
//print(SCALE_MAX,"  ",SCALE_MAX_TEST, "  ", SCALE_MAX/SCALE_MAX_TEST,"\n");


// internal variables used by bpc function
const float OCES_BP_HDR = 0.0001;   // luminance of OCES black point. 
                                      // (to be mapped to device black point)
const float OCES_WP_HDR = OCES_WP_VIDEO;     // luminance of OCES white point 
                                      // (to be mapped to device white point)
const float OUT_BP_HDR = OUT_BP;      // luminance of output device black point 
                                      // (to which OCES black point is mapped)
const float OUT_WP_HDR = OUT_WP_VIDEO; // luminance of output device nominal white point
                                      // (to which OCES black point is mapped)
const float BPC_HDR = (OCES_BP_HDR * OUT_WP_HDR - OCES_WP_HDR * OUT_BP_HDR) / (OCES_BP_HDR - OCES_WP_HDR);
const float SCALE_HDR = (OUT_BP_HDR - OUT_WP_HDR) / (OCES_BP_HDR - OCES_WP_HDR); 
// from odt-transforms:                                     
// bpc_fwd( rgb, SCALE_VIDEO, BPC_VIDEO, OUT_BP_VIDEO, OUT_WP_VIDEO);
// BPC_VIDEO = (OCES_BP_VIDEO * OUT_WP_VIDEO - OCES_WP_VIDEO * OUT_BP_VIDEO) / (OCES_BP_VIDEO - OCES_WP_VIDEO);
// SCALE_VIDEO = (OUT_BP_VIDEO - OUT_WP_VIDEO) / (OCES_BP_VIDEO - OCES_WP_VIDEO);  

                                  	
  /* --- Initialize a 3-element vector with input variables (OCES) --- */
    float oces[3] = { rIn, gIn, bIn};
    
  /* -- scale to put image through top of tone scale */
  float ocesScale[3];
	  ocesScale[0] = oces[0]/SCALE_MAX;
	  ocesScale[1] = oces[1]/SCALE_MAX;
	  ocesScale[2] = oces[2]/SCALE_MAX; 
	  
  /* --- Apply hue-preserving tone scale with saturation preservation --- */
   float rgbPost[3] = odt_tonescale_fwd_f3( ocesScale);
    
  /* scale image back to proper range */
   rgbPost[0] = SCALE_MAX * rgbPost[0];
   rgbPost[1] = SCALE_MAX * rgbPost[1];
   rgbPost[2] = SCALE_MAX * rgbPost[2];      
    
// Restore any values that would have been below 0.0001 going into the tone curve
// basically when oces is divided by SCALE_MAX (ocesScale) any value below 0.0001 will be clipped
   if(ocesScale[0] < OCESMIN) rgbPost[0] = oces[0];
   if(ocesScale[1] < OCESMIN) rgbPost[1] = oces[1];
   if(ocesScale[2] < OCESMIN) rgbPost[2] = oces[2];
    

  /* --- Apply black point compensation --- */  
   float linearCV[3] = bpc_fwd( rgbPost, SCALE_HDR, BPC_HDR, OUT_BP_HDR, OUT_WP_MAX_PQ); // bpc_cinema_fwd( rgbPost);
   linearCV = clamp_f3(linearCV,FLT_MIN,OUT_WP_MAX_PQ);
    
  /* --- Convert to display primary encoding --- */
    // OCES RGB to CIE XYZ
    float XYZ[3] = mult_f3_f44( linearCV, OCES_PRI_2_XYZ_MAT);


  /* --- Handle out-of-gamut values --- */
    // Clip to P3 gamut using hue-preserving clip
    XYZ = huePreservingClip_to_p3d60( XYZ);


    // Apply CAT from ACES white point to assumed observer adapted white point
    XYZ = mult_f3_f33( XYZ, D60_2_D65_CAT);
  int inds[3] = order3( XYZ[0], XYZ[1], XYZ[2]);
  if(XYZ[inds[2]]<0.0){
	  print("XYZ", XYZ[inds[2]]);
  }
  

 
  // Convert to P3
  float tmp[3] = mult_f3_f44( XYZ, XYZ_2_DISPLAY_PRI_MAT); 
  
  /* Desaturate negative values going to DISPLAY Gamut */
  //inds = order3( tmp[0], tmp[1], tmp[2]);
  //if(tmp[inds[2]]<0.0){
	  //float origY = tmp[1];
	  //tmp[inds[2]]= -tmp[inds[2]]*1.3 + tmp[inds[2]];
	  //tmp[inds[1]]= -tmp[inds[2]]*1.3 + tmp[inds[1]];
	  //tmp[inds[0]]= -tmp[inds[2]]*1.3 + tmp[inds[0]];
	  //float newXYZ[3] = mult_f3_f44( tmp, DISPLAY_PRI_2_XYZ_MAT);
	  //float scaleY = fabs(origY/newXYZ[1]);
	  //tmp = mult_f_f3(scaleY,tmp);
  //}
  if (ALARM)
  {
	  if(tmp[0]<0.0) tmp[0] = 5000.0;
	  if(tmp[1]<0.0) tmp[1] = 5000.0;
	  if(tmp[2]<0.0) tmp[2] = 5000.0;
  }


  // clamp to 10% if 1k (RATIO) or 1k nits and scale output to go from 0-1k nits across whole code value range 
  // don't clamp at RATIO because tone curve is the ultimate limit
  float tmp2[3] = clamp_f3(tmp,0.,OUT_WP_MAX_PQ); // no clamp is 1.0 , clamp if RATIO


  float cctf[3]; 
  cctf[0] = CV_BLACK + (CV_WHITE - CV_BLACK) * PQ10000_r(tmp2[0]);
  cctf[1] = CV_BLACK + (CV_WHITE - CV_BLACK) * PQ10000_r(tmp2[1]);
  cctf[2] = CV_BLACK + (CV_WHITE - CV_BLACK) * PQ10000_r(tmp2[2]); 
  

  float outputCV[3] = clamp_f3( cctf, 0., pow( 2, BITDEPTH)-1);

  // This step converts integer CV back into 0-1 which is what CTL expects
  outputCV = mult_f_f3( 1./(pow(2,BITDEPTH)-1), outputCV);

  /*--- Cast outputCV to rOut, gOut, bOut ---*/
  rOut = outputCV[0];
  gOut = outputCV[1];
  bOut = outputCV[2];
  //aOut = aIn;
}
