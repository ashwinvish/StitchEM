# Thomas Macrina
# 150323
# Jython conversion of BlockMatching_ExtractPoinRoi (sic)
# http://fiji.sc/git/?p=fiji.git;a=blob;f=src-plugins/blockmatching_/mpicbg/ij/plugin/BlockMatching_ExtractPoinRoi.java;h=2e9daf810b81110ee899e12c236c3864ab09ed89;hb=1861dafff1162f64051393a7e5ef71f0426f5bf6

import os
from ij import IJ
from ij import ImagePlus
from ij import WindowManager
from ij.io import FileSaver 
from ij.gui import GenericDialog
from ij.gui import PointRoi
from ij.process import ColorProcessor
from ij.process import FloatProcessor

from java.util import ArrayList
from java.util import Set

from mpicbg.ij.blockmatching import BlockMatching
from mpicbg.models import PointMatch
from mpicbg.ij.util.Util import pointsToPointRoi
from mpicbg.ij.util.Util import colorVector
from mpicbg.models import ErrorStatistic
from mpicbg.models import SpringMesh
from mpicbg.models import TranslationModel2D
from mpicbg.trakem2.align import Util

from net.imglib2 import RealPoint
from net.imglib2 import KDTree
from net.imglib2 import RealPointSampleList
from net.imglib2.exception import ImgLibException
from net.imglib2.img.imageplus import ImagePlusImg
from net.imglib2.img.imageplus import ImagePlusImgFactory
from net.imglib2.neighborsearch import NearestNeighborSearchOnKDTree
from net.imglib2.type.numeric import ARGBType
from script.imglib import ImgLib

from mpicbg.util import Timer

import threading
import time
from java.util.concurrent import Callable
from java.util.concurrent import Executors, TimeUnit

from script.imglib.algorithm import Scale2D

class BlockMatcherParameters():
	def __init__(self,
			input_folder = "/mnt/data0/tommy/150318_debug_block_matching/",
			output_folder = "/mnt/data0/tommy/150325_block_match_vector_plots_smoothness/",
			export_point_roi = True,
			export_displacement_vectors = True,
			scale = 1.00,
			search_radius = 35,
			block_radius = 35,
			mesh_resolution = 32,
			min_R = 0.6,
			max_curvature_R = 10,
			rod_R = 1,
			use_local_smoothness_filter = True,
			local_model_index = 1,
			local_region_sigma = 360,
			max_local_epsilon = 6,
			max_local_trust = 999999,
			num_points_in_smoothness = 6):
		self.input_folder = input_folder
		self.output_folder = output_folder

		self.export_point_roi = export_point_roi
		self.export_displacement_vectors = export_displacement_vectors

		self.scale = scale
		self.search_radius = search_radius
		self.block_radius = block_radius
		self.mesh_resolution = mesh_resolution
		self.min_R = min_R
		self.max_curvature_R = max_curvature_R
		self.rod_R = rod_R
		self.use_local_smoothness_filter = use_local_smoothness_filter
		self.local_model_index = local_model_index # 0: Translation, 1: Rigid, 2: Similarity, 3: Affine
		self.local_region_sigma = local_region_sigma
		self.max_local_epsilon = max_local_epsilon
		self.max_local_trust = max_local_trust
		self.num_points_in_smoothness = num_points_in_smoothness

class BlockMatcher(Callable):
	def __init__(self, imgA, imgB, params, wf=None):
		self.imgA = imgA
		self.imgB = imgB
		self.params = params
		self.wf = wf

		self.started = None
		self.completed = None
		self.thread_used = None
		self.exception = None

	# With help from
	# http://albert.rierol.net/imagej_programming_tutorials.html#ImageJ%20programming%20basics
	def scaleIntImagePlus(self, intImgPlus, scale):
		imgPlus = intImgPlus.getImagePlus()
		ip = imgPlus.getProcessor()
		new_width = int(ip.getWidth()*scale)
		new_height = int(ip.getHeight()*scale)
		ip2 = ip.resize(new_width, new_height)
		imgPlus.setProcessor(imgPlus.getTitle(), ip2)
		return imgPlus

	# Adapted from AbstractBlockMatching.java
	# http://fiji.sc/git/?p=fiji.git;a=blob;f=src-plugins/blockmatching_/mpicbg/ij/plugin/AbstractBlockMatching.java;h=9dfebf1d807544173c763051ba45f6a65fccafad;hb=1861dafff1162f64051393a7e5ef71f0426f5bf6
	def createMask(self, source):
		mask = FloatProcessor(source.getWidth(), source.getHeight())
		maskColor = 0x0000ff00
		sourcePixels = source.getPixels()
		n = len(sourcePixels)
		maskPixels = mask.getPixels()
		for i in xrange(n):
			sourcePixel = sourcePixels[i] & 0x00ffffff
			if sourcePixel == maskColor:
				maskPixels[i] = 0
			else:
				maskPixels[i] = 1
		mask.setPixels(maskPixels)
		return mask

	# Adapted from AbstractBlockMatching.java
	# http://fiji.sc/git/?p=fiji.git;a=blob;f=src-plugins/blockmatching_/mpicbg/ij/plugin/AbstractBlockMatching.java;h=9dfebf1d807544173c763051ba45f6a65fccafad;hb=1861dafff1162f64051393a7e5ef71f0426f5bf6
	def matches2ColorSamples(self, matches):
		samples = RealPointSampleList(2)
		maxX = 1
		maxY = 1
		for match in matches:
			p = match.getP1().getL()
			q = match.getP2().getW()
			if q[0] - p[0] > maxX:
				maxX = q[0] - p[0]
			if q[1] - p[1] > maxY:
				maxY = q[1] - p[1]
		max_color = maxX
		if maxY > max_color:
			max_color = maxY
		for match in matches:
			p = match.getP1().getL()
			q = match.getP2().getW()
			dx = (q[0] - p[0]) / max_color
			dy = (q[1] - p[1]) / max_color
			rgb = colorVector(dx, dy)
			samples.add(RealPoint(p), ARGBType(rgb))
		return samples, max_color


	# Adapted from AbstractBlockMatching.java
	# http://fiji.sc/git/?p=fiji.git;a=blob;f=src-plugins/blockmatching_/mpicbg/ij/plugin/AbstractBlockMatching.java;h=9dfebf1d807544173c763051ba45f6a65fccafad;hb=1861dafff1162f64051393a7e5ef71f0426f5bf6
	def drawNearestNeighbor(self, target, nnSearchSamples, nnSearchMask):
		timer = Timer()
		timer.start()
		c = target.localizingCursor()
		while c.hasNext():
			c.fwd()
			c.get().set(ARGBType(-1))
			nnSearchSamples.search(c)
			nnSearchMask.search(c)
			if nnSearchSamples.getSquareDistance() <= nnSearchMask.getSquareDistance():
				c.get().set(nnSearchSamples.getSampler().get())
			else:
				c.get().set(nnSearchMask.getSampler().get())
		return timer.stop()

	def writePointsFile(self, points, filename):
		fn = open(filename, 'w')
		for match in points:
			x1 = match.getP1().getL()[0]
			y1 = match.getP1().getL()[1]
			x2 = match.getP2().getW()[0]
			y2 = match.getP2().getW()[1]
			fn.write(str(x1) + "\t" + str(y1) + "\t" + str(x2) + "\t" + str(y2) + "\n")		

	def call(self):
		self.thread_used = threading.currentThread().getName()
		self.started = time.time()
		try:
			filenames = os.listdir(self.params.input_folder)
			filenames.sort()

			imp1 = IJ.openImage(os.path.join(self.params.input_folder, filenames[self.imgA]))
			imp2 = IJ.openImage(os.path.join(self.params.input_folder, filenames[self.imgB]))
			IJ.log(time.asctime())
			IJ.log(str(self.imgA) + ": " + str(imp1))
			IJ.log(str(self.imgB) + ": " + str(imp2))			
			print str(self.imgA) + ": " + str(imp1)
			print str(self.imgB) + ": " + str(imp2)

			# w_n = e^((num_points_in_smoothness*point_distance)^2 / (-2*local_region_sigma^2))
			# point_distance = image_width / mesh_resolution
			# We'll adjust the mesh_resolution to get the point_distance, so that the 
			# nth point has a weight of at least 0.01
			# Plug in values to above equation and solve for point_distance
			# (num_points_in_smoothness*point_distance)^2 / local_region_sigma^2 = -2*ln(w_n)
			# point_distance = local_region_sigma * (-2*ln(0.01))^(1/2) / num_points_in_smoothness
			# (-2*ln(0.01))^(1/2) ~= 3
			point_distance = self.params.local_region_sigma * 3 / self.params.num_points_in_smoothness
			self.params.mesh_resolution = int(imp1.getWidth() / point_distance)
			effective_point_distance = imp1.getWidth() / self.params.mesh_resolution
			effective_local_region_sigma =  effective_point_distance * self.params.num_points_in_smoothness / 3

			mesh = SpringMesh(self.params.mesh_resolution, imp1.getWidth(), imp1.getHeight(), 1, 1000, 0.9)
			vertices = mesh.getVertices()
			maskSamples = RealPointSampleList(2)
			for vertex in vertices:
				maskSamples.add(RealPoint(vertex.getL()), ARGBType(-1)) # equivalent of 0xffffffff
			pm12 = ArrayList()
			v1 = mesh.getVertices()

			ip1 = imp1.getProcessor().convertToFloat().duplicate()
			ip2 = imp2.getProcessor().convertToFloat().duplicate()

			ip1Mask = self.createMask(imp1.getProcessor().convertToRGB())
			ip2Mask = self.createMask(imp2.getProcessor().convertToRGB())

			ct = TranslationModel2D()

			BlockMatching.matchByMaximalPMCC(
							ip1,
							ip2,
							ip1Mask,
							ip2Mask,
							self.params.scale,
							ct,
							self.params.block_radius,
							self.params.block_radius,
							self.params.search_radius,
							self.params.search_radius,
							self.params.min_R,
							self.params.rod_R,
							self.params.max_curvature_R,
							v1,
							pm12,
							ErrorStatistic(1))

			pre_smooth_block_matches = len(pm12)
			pre_smooth_filename = self.params.output_folder + str(imp2.getTitle())[:-4] + "_" + str(imp1.getTitle())[:-4] + "_pre_smooth_pts.txt"
			self.writePointsFile(pm12, pre_smooth_filename)

			if self.params.use_local_smoothness_filter:
				model = Util.createModel(self.params.local_model_index)
				try:
					model.localSmoothnessFilter(pm12, pm12, effective_local_region_sigma, self.params.max_local_epsilon, self.params.max_local_trust)
					post_smooth_filename = self.params.output_folder + str(imp2.getTitle())[:-4] + "_" + str(imp1.getTitle())[:-4] + "_post_smooth_pts.txt"
					self.writePointsFile(pm12, post_smooth_filename)
				except:
					pm12.clear()

			color_samples, max_displacement = self.matches2ColorSamples(pm12)
			post_smooth_block_matches = len(pm12)
				
			print time.asctime()
			print str(self.imgB) + "_" + str(self.imgA) + "\tblock_matches\t" + str(pre_smooth_block_matches) + "\tsmooth_matches\t" + str(post_smooth_block_matches) + "\tmax_displacement\t" + str(max_displacement) + "\trelaxed_length\t" + str(int(imp1.getWidth()/self.params.mesh_resolution))
			IJ.log(time.asctime())
			IJ.log(str(self.imgB) + "_" + str(self.imgA) + "\tblock_matches\t" + str(pre_smooth_block_matches) + "\tsmooth_matches\t" + str(post_smooth_block_matches) + "\tmax_displacement\t" + str(max_displacement))
			if self.wf:
				self.wf.write(str(self.imgB) + "\t" + str(self.imgA) + "\t" + str(imp2.getTitle())[:-4] + "\t" + str(imp1.getTitle())[:-4] + "\t" + str(pre_smooth_block_matches) + "\t" + str(pre_smooth_block_matches - post_smooth_block_matches) + "\t" + str(max_displacement) + "\t" + str(effective_point_distance) + "\t" + str(effective_local_region_sigma) + "\n")

			if self.params.export_point_roi:
				pm12Sources = ArrayList()
				pm12Targets = ArrayList()

				PointMatch.sourcePoints(pm12, pm12Sources)
				PointMatch.targetPoints(pm12, pm12Targets)

				roi1 = pointsToPointRoi(pm12Sources)
				roi2 = pointsToPointRoi(pm12Targets)

				imp1.setRoi(roi1)
				imp2.setRoi(roi2)

			if self.params.export_displacement_vectors:
				pm12Targets = ArrayList()
				PointMatch.targetPoints(pm12, pm12Targets)

				maskSamples2 = RealPointSampleList(2)
				for point in pm12Targets:
					maskSamples2.add(RealPoint(point.getW()), ARGBType(-1))
				factory = ImagePlusImgFactory()
				kdtreeMatches = KDTree(color_samples)
				kdtreeMask = KDTree(maskSamples)
				
				img = factory.create([imp1.getWidth(), imp1.getHeight()], ARGBType())
				self.drawNearestNeighbor(
							img, 
							NearestNeighborSearchOnKDTree(kdtreeMatches),
							NearestNeighborSearchOnKDTree(kdtreeMask))
				scaled_img = self.scaleIntImagePlus(img, 0.1)
				# scaled_img.show()
				fs = FileSaver(scaled_img)
				fs.saveAsTiff(self.params.output_folder + str(imp2.getTitle())[:-4] + "_" + str(imp1.getTitle()))
				print time.asctime()
				print str(self.imgB) + "_" + str(self.imgA) + "\tsaved\t" + filenames[self.imgB]
				IJ.log(time.asctime())
				IJ.log(str(self.imgB) + "_" + str(self.imgA) + "\tsaved\t" + filenames[self.imgB])
		except Exception, ex:
			self.exception = ex
			print str(ex)
			IJ.log(str(ex))
			if self.wf:
				self.wf.write(str(ex) + "\n")
		self.completed = time.time()
		return self
		# return pm12, vertices, maskSamples
		# return pm12Sources, pm12Targets


def shutdownAndAwaitTermination(pool, timeout):
	pool.shutdown()
	try:
		if not pool.awaitTermination(timeout, TimeUnit.SECONDS):
			pool.shutdownNow()
			if (not pool.awaitTermination(timeout, TimeUnit.SECONDS)):
				print >> sys.stderr, "Pool did not terminate"
	except InterruptedException, ex:
		# (Re-)Cancel if current thread also interrupted
		pool.shutdownNow()
		# Preserve interrupt status
		Thread.currentThread().interrupt()

def runBlockMatching(wafer_title):
	MAX_CONCURRENT = 20
	input_folder = "/mnt/data0/tommy/150318_debug_block_matching/" + wafer_title + "/"
	# input_folder = "/home/seunglab/tommy/" + wafer_title + "/affine_renders_0175x/"
	# input_folder = "/mnt/data0/tommy/tests/150409_elastic_solver_sensitivity/elastic_images/"
	output_folder = "/mnt/data0/tommy/150325_block_match_vector_plots_smoothness/" + wafer_title + "/"
	# output_folder = "/home/seunglab/tommy/" + wafer_title + "/150324_block_match_vector_plots/"
	# output_folder = "/mnt/data0/tommy/tests/150409_elastic_solver_sensitivity/elastic_block_matching/"
	start = 1
	finish = len(os.listdir(input_folder))
	params = BlockMatcherParameters(input_folder=input_folder, output_folder=output_folder)

	# Log file
	t = time.localtime()
	ts = str(t[0]) + str(t[1]) + str(t[2]) + str(t[3]) + str(t[4]) + str(t[5])
	writefile = output_folder + ts + "_block_matching_loop_log.txt"
	wf = open(writefile, 'w')
	wf.write(time.asctime() + "\n")
	wf.write(writefile + "\n")
	param_values = vars(params)
	for key in param_values:
		wf.write(key + "\t" + str(param_values[key]) + "\n")
	wf.write("B_idx\tA_idx\tB_file\tA_file\tmatches\tsmooth\tmax_displacement\tdistance\tlocal_sigma\n")

	image_pairs = [(i-1, i) for i in range(start,finish)]

	pool = Executors.newFixedThreadPool(MAX_CONCURRENT)
	block_matchers = [BlockMatcher(pair[0], pair[1], params, wf) for pair in image_pairs]
	futures = pool.invokeAll(block_matchers)

	for future in futures:
		print future.get(5, TimeUnit.SECONDS)

	wf.write(time.asctime() + "\n")
	wf.close()
	shutdownAndAwaitTermination(pool, 5)

# runBlockMatching('')

# Cycle through images
# wafer_title = "S2-W004"
# runBlockMatching(wafer_title)
wafer_title = "S2-W001"
runBlockMatching(wafer_title)
