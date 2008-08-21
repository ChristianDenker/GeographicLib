/**
 * \file Constants.hpp
 *
 * Copyright (c) Charles Karney (2008) <charles@karney.com>
 * and licensed under the LGPL.
 **********************************************************************/

#if !defined(CONSTANTS_HPP)
#define CONSTANTS_HPP "$Id$"

namespace GeographicLib {

  class Constants {
  public:
    static const double pi, degree, huge, WGS84_a, WGS84_invf, UPS_k0, UTM_k0;
  };

} // namespace GeographicLib

#endif
