require "big"
require "math"

class SphericalMercator
  VERSION = "0.1.0"

  DEFAULT_SIZE = 256.as(Int32)
  R2D          = 180 / Math::PI
  D2R          = Math::PI / 180
  # 900913 properties.
  A         =          6378137.0
  MAXEXTENT = 20037508.342789244

  def initialize(@size = DEFAULT_SIZE)
    @Bc = [] of Float64
    @Cc = [] of Float64
    @zc = [] of Float64
    @Ac = [] of Float64

    size = (@size * 1.0).as(Float64)
    0.upto(30) do |d|
      @Bc.push((size / 360.0).as(Float64))
      @Cc.push((size / (2 * Math::PI).as(Float64)))
      @zc.push((size / 2.0).as(Float64))
      @Ac.push((size * 1.0).as(Float64))
      size = size*2
    end
  end

  # Convert tile xyz value to bbox of the form `[w, s, e, n]`
  # - `x` {Number} x (longitude) number.
  # - `y` {Number} y (latitude) number.
  # - `zoom` {Number} zoom.
  # - `tms_style` {Boolean} whether to compute using tms-style.
  # - `srs` {String} projection for resulting bbox (WGS84|900913).
  # - `return` {Array} bbox array of values in form `[w, s, e, n]`.
  def bbox(x, y, zoom, tms_style = false, srs = "WGS84")
    # Convert xyz into bbox with srs WGS84
    if tms_style
      y = ((2**zoom) - 1) - y
    end

    # lower left
    ll = [x * @size, (y + 1) * @size]

    # upper right
    ur = [(x + 1) * @size, y * @size]

    bbox = ll(ll, zoom).concat(ll(ur, zoom))

    # If web mercator requested reproject to 900913.
    if srs == "900913"
      convert(bbox, "900913")
    else
      bbox
    end
  end

  # Convert bbox to xyx bounds
  #
  # - `bbox` {Number} bbox in the form `[w, s, e, n]`.
  # - `zoom` {Number} zoom.
  # - `tms_style` {Boolean} whether to compute using tms-style.
  # - `srs` {String} projection of input bbox (WGS84|900913).
  # - `@return` {Object} XYZ bounds containing minX, maxX, minY, maxY properties.
  def xyz(bbox, zoom, tms_style = false, srs = "WGS84")
    # If web mercator provided reproject to WGS84.
    if srs == "900913"
      bbox = convert(bbox, "WGS84")
    end

    ll = [bbox[0], bbox[1]]
    ur = [bbox[2], bbox[3]]
    px_ll = px(ll, zoom)
    px_ur = px(ur, zoom)

    # Y = 0 for XYZ is the top hence minY uses px_ur[1].
    x = [
      (px_ll[0] / @size).floor,
      ((px_ur[0] - 1) / @size).floor,
    ]

    y = [
      (px_ur[1] / @size).floor,
      ((px_ll[1] - 1) / @size).floor,
    ]

    minX = Math.min(x[0], x[1])
    minY = Math.min(y[0], y[1])

    bounds = {
      :minX => minX < 0 ? 0 : minX,
      :minY => minY < 0 ? 0 : minY,
      :maxX => Math.max(x[0], x[1]),
      :maxY => Math.max(y[0], y[1]),
    }

    if tms_style
      tms = {
        :minY => ((2**zoom) - 1) - bounds[:maxY],
        :maxY => ((2**zoom) - 1) - bounds[:minY],
      }

      bounds[:minY] = tms[:minY]
      bounds[:maxY] = tms[:maxY]
    end

    bounds
  end

  def px(ll, zoom)
    if zoom.is_a?(Float64)
      size = @size * 2**zoom
      d = size / 2
      bc = (size / 360)
      cc = (size / (2 * Math::PI))
      ac = size * 1.0
      f = Math.min(Math.max(Math.sin(D2R * ll[1]), -0.9999), 0.9999)
      x = d + ll[0] * bc
      y = d + 0.5 * Math.log((1 + f) / (1 - f)) * -cc
      x = ac if x > ac
      y = ac if y > ac
    else
      d = @zc[zoom]
      f = Math.min(Math.max(Math.sin(D2R * ll[1]), -0.9999), 0.9999)
      x = (d + ll[0] * @Bc[zoom]).floor
      y = (d + 0.5 * Math.log((1 + f) / (1 - f)) * (-@Cc[zoom])).floor
      x = @Ac[zoom] if x > @Ac[zoom]
      y = @Ac[zoom] if y > @Ac[zoom]
    end

    [x, y]
  end

  # Convert screen pixel value to lon lat
  #
  # - `px` {Array} `[x, y]` array of geographic coordinates.
  # - `zoom` {Number} zoom level.
  def ll(px, zoom)
    if zoom.is_a?(Float64)
      size = @size * 2**zoom
      bc = size / 360
      cc = size / (2 * Math::PI)
      zc = size / 2
      g = (px[1] - zc) / -cc
      lon = (px[0] - zc) / bc
    else
      g = (px[1] - @zc[zoom]) / -@Cc[zoom]
      lon = (px[0] - @zc[zoom]) / @Bc[zoom]
    end

    lat = R2D * (2 * Math.atan(Math.exp(g)) - 0.5 * Math::PI)

    [lon, lat]
  end

  # Convert projection of given bbox.
  #
  # - `bbox` {Number} bbox in the form `[w, s, e, n]`.
  # - `to` {String} projection of output bbox (WGS84|900913). Input bbox
  #   assumed to be the "other" projection.
  # - `@return` {Object} bbox with reprojected coordinates.
  def convert(bbox, to = "WGS84")
    if to == "900913"
      forward(bbox[0, 2]).concat(forward(bbox[2, 4]))
    else
      inverse(bbox[0, 2]).concat(inverse(bbox[2, 4]))
    end
  end

  # Convert lon/lat values to 900913 x/y.
  def forward(ll)
    xy = [
      A * ll[0] * D2R,
      A * Math.log(Math.tan((Math::PI*0.25) + (0.5 * ll[1] * D2R))),
    ]

    # if xy value is beyond maxextent (e.g. poles), return maxextent.
    0.upto(1) do |i|
      xy[i] = MAXEXTENT if xy[i] > MAXEXTENT
      xy[i] = -MAXEXTENT if xy[i] < -MAXEXTENT
    end

    xy
  end

  # Convert 900913 x/y values to lon/lat.
  def inverse(xy)
    [
      (xy[0] * R2D / A),
      ((Math::PI*0.5) - 2.0 * Math.atan(Math.exp(-xy[1] / A))) * R2D,
    ]
  end
end
