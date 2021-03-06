//  XYZ to 2020 primaries


import "utilities";
import "utilities-color";

const float XYZ_2_2020_PRI_MAT[4][4] = XYZtoRGB(REC2020_PRI,1.0);


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
  // Put input variables (XYZ) into a 3-element vector
  float XYZ[3] = {rIn, gIn, bIn};

    // Convert from XYZ to Display primaries
    float RGB[3] = mult_f3_f44( XYZ, XYZ_2_2020_PRI_MAT);

  rOut = RGB[0];
  gOut = RGB[1];
  bOut = RGB[2];
  //aOut = aIn;
}
