

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

  rOut = gIn;
  gOut = bIn;
  bOut = rIn;
  //aOut = aIn;
}
