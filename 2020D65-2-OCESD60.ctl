// 709 Matrix only (hopefully!)

import "utilities";
import "utilities-color";
import "transforms-common";
import "odt-transforms-common";


/* ----- ODT Parameters ------ */
const Chromaticities DISPLAY_PRI = REC2020_PRI;
const float DISPLAY_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(DISPLAY_PRI,1.0);
const float XYZ_2_ACES_PRI_MAT[4][4] = XYZtoRGB(ACES_PRI,1.0);


const unsigned int BITDEPTH = 16;
const unsigned int CV_BLACK = 0;
const unsigned int CV_WHITE = pow( 2, BITDEPTH) - 1;

void main 
(
  input varying float rIn, 
  input varying float gIn, 
  input varying float bIn, 
  output varying float rOut,
  output varying float gOut,
  output varying float bOut 
)
{

  float R2020Linear[3] = {rIn, gIn, bIn};
  
  // CIE XYZ to display primaries
  float XYZ[3] = mult_f3_f44( R2020Linear, DISPLAY_PRI_2_XYZ_MAT);
  
      // Apply CAT from assumed observer adapted white to ACES white point
      XYZ = mult_f3_f33( XYZ, invert_f33( D60_2_D65_CAT));  

  float rgbOut[3] = mult_f3_f44( XYZ, XYZ_2_ACES_PRI_MAT);
  
  /*--- Cast outputCV to rOut, gOut, bOut ---*/
  rOut = rgbOut[0];
  gOut = rgbOut[1];
  bOut = rgbOut[2];
  //aOut = aIn;
}
