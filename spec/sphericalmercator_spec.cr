require "./spec_helper"
require "random"

MAX_EXTENT_MERC = [-20037508.342789244,-20037508.342789244,20037508.342789244,20037508.342789244]
MAX_EXTENT_WGS84 = [-180,-85.0511287798066,180,85.0511287798066]

describe Sphericalmercator do

  sm = Sphericalmercator.new

  describe "#bbox" do
    it "calculates bbox for [0, 0, 0]" do
      sm.bbox(0, 0, 0, true, "WGS84").should eq([-180,-85.05112877980659,180,85.0511287798066])
    end

    it "calculates bbox for [0, 0, 1]" do
      sm.bbox(0, 0, 1, true, "WGS84").should eq([-180,-85.05112877980659,0,0])
    end
  end

  describe "#xyz" do
    it "World extents converted to proper tile ranges" do
      sm.xyz([-180, -85.05112877980659, 180, 85.0511287798066],0, true, "WGS84").
        should eq({:minX => 0, :minY =>0, :maxX => 0, :maxY => 0})
    end

    it "SW converted to proper tile ranges" do
      sm.xyz([-180, -85.05112877980659, 0, 0], 1, true, "WGS84").
        should eq({:minX =>0, :minY => 0, :maxX => 0, :maxY => 0})
    end

    it "xyz-broken" do
      extent = [-0.087891, 40.95703, 0.087891, 41.044916]
      xyz = sm.xyz(extent, 3, true, "WGS84")
      (xyz[:minX] <= xyz[:maxX]).should be_true
      (xyz[:minY] <= xyz[:maxY]).should be_true
    end

    it "works for negative values" do
      extent = [-112.5, 85.0511, -112.5, 85.0511]
      xyz = sm.xyz(extent, 0)
      xyz[:minY].should eq(0)
    end

    it "xyz-fuzz" do
      0.upto(1000) do |i|
        x = [-180 + (360*Random.rand), -180 + (360*Random.rand)];
        y = [-85 + (170*Random.rand), -85 + (170*Random.rand)];
        z = 22*Random.rand.floor
        extent = [
          Math.min(x[0], x[1]),
          Math.min(y[0], y[1]),
          Math.max(x[0], x[1]),
          Math.max(y[0], y[1])
        ]
        xyz = sm.xyz(extent, z, true, "WGS84")
        if xyz[:minX] > xyz[:maxX]
          (xyz[:minX] <= xyz[:maxX]).should be_true
        end
        if xyz[:minX] > xyz[:maxX]
          (xyz[:minY] <= xyz[:maxY]).should be_true
        end
      end
    end
  end

  describe "#convert" do
    it "should convert to MERC" do
      sm.convert(MAX_EXTENT_WGS84, "900913").should eq(MAX_EXTENT_MERC)
    end

    it "should convert to WGS84" do
      sm.convert(MAX_EXTENT_MERC, "WGS84").should eq(MAX_EXTENT_WGS84)
    end
  end

  describe "#extents" do
    it "should convert" do
      sm.convert([-240,-90,240,90],"900913").should eq(MAX_EXTENT_MERC)
    end

    it "Maximum extents enforced on conversion to tile ranges" do
      sm.xyz([-240,-90,240,90], 4, true, "WGS84").
        should eq({
          :minX => 0,
          :minY => 0,
          :maxX => 15,
          :maxY => 15
      })
    end
  end

  describe "#ll" do
    it "should work with int" do
      sm.ll([200,200], 9).should eq([-179.45068359375, 85.00351401304403])
    end

    it "should work with float" do
      sm.ll([200,200], 8.6574).should eq([-179.3034449476476, 84.99067388699072])
    end
  end

  describe "#px" do
    it "PX with int zoom value converts" do
      # FIXME: Crystal rounds to integer using floor, so the original value was [364, 214]
      sm.px([-179,85], 9).should eq([364, 214])
    end

    it "PX with float zoom value converts" do
      sm.px([-179,85], 8.6574).should eq([287.12734093961626, 169.30444219392666])
    end
  end

  describe "high precision float" do
    it "first 6 decimals are the same" do
      with_int = sm.ll([200,200], 4)
      with_float = sm.ll([200,200], 4.0000000001)

      with_int[0].round(6).should eq(with_float[0].round(6))
      with_int[1].round(6).should eq(with_float[1].round(6))
    end
  end
end
