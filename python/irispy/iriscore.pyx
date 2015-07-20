import itertools
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import colorConverter
import mpl_toolkits.mplot3d as a3
import scipy.spatial
cimport numpy as np
from cython.view cimport array as cvarray
from cython.operator cimport dereference as deref
from iriscore cimport inflate_region as cinflate_region

cdef eigenMatrixToNumpy(const MatrixXd &M):
    cdef cvarray = <double[:M.rows(),:M.cols()]> <double*> M.data()
    return np.asarray(cvarray).copy()

cdef eigenVectorToNumpy(const VectorXd &v):
    cdef cvarray = <double[:v.size()]> <double*> v.data()
    return np.asarray(cvarray).copy()

cdef class Polytope:
    cdef shared_ptr[CPolytope] thisptr
    def __cinit__(self, dim=0, construct_new_cpp_object=True):
        if construct_new_cpp_object:
            self.thisptr = shared_ptr[CPolytope](new CPolytope(dim))
    @staticmethod
    cdef wrap(shared_ptr[CPolytope] ptr):
        pyobj = Polytope(construct_new_cpp_object=False)
        pyobj.thisptr = ptr
        return pyobj

    def getDimension(self):
        return self.thisptr.get().getDimension()
    def setA(self, np.ndarray[double, ndim=2, mode="c"] A not None):
        cdef MatrixXd A_mat = copyToMatrix(&A[0,0], A.shape[0], A.shape[1])
        self.thisptr.get().setA(A_mat)
    def getA(self):
        return eigenMatrixToNumpy(self.thisptr.get().getA())
    def setB(self, np.ndarray[double, ndim=1, mode="c"] b not None):
        cdef VectorXd b_vec = copyToVector(&b[0], b.shape[0])
        self.thisptr.get().setB(b_vec)
    def getB(self):
        return eigenVectorToNumpy(self.thisptr.get().getB())
    def appendConstraints(self, Polytope other):
        self.thisptr.get().appendConstraints(deref(other.thisptr))
    def generatorPoints(self):
        cdef vector[VectorXd] pts = self.thisptr.get().generatorPoints()
        return [eigenVectorToNumpy(pt) for pt in pts]
    def generatorRays(self):
        cdef vector[VectorXd] pts = self.thisptr.get().generatorRays()
        return [eigenVectorToNumpy(pt) for pt in pts]
    def draw(self, ax=None, **kwargs):
        if self.getDimension() == 2:
            self.draw2d(ax=ax, **kwargs)
        elif self.getDimension() == 3:
            self.draw3d(ax=ax, **kwargs)
        else:
            raise NotImplementedError("drawing for polytopes of dimension greater than 3 not implemented yet")
    def draw2d(self, ax=None, **kwargs):
        if ax is None:
            ax = plt.gca()
        points = np.vstack(self.generatorPoints())
        hull = scipy.spatial.ConvexHull(points)
        kwargs.setdefault("edgecolor", "r")
        kwargs.setdefault("facecolor", "none")
        ax.add_patch(plt.Polygon(xy=points[hull.vertices],**kwargs))
    def draw3d(self, ax=None, **kwargs):
        if ax is None:
            ax = a3.Axes3D(plt.gcf())
        points = np.vstack(self.generatorPoints())
        hull = scipy.spatial.ConvexHull(points)
        kwargs.setdefault("color", "r")
        kwargs.setdefault("alpha", 1.0)
        kwargs["facecolor"] = colorConverter.to_rgba(kwargs["color"], kwargs["alpha"])
        for simplex in hull.simplices:
            poly = a3.art3d.Poly3DCollection([points[simplex]], **kwargs)
            if "alpha" in kwargs:
                print "setting alpha"
                poly.set_alpha(kwargs["alpha"])
            ax.add_collection3d(poly)


cdef class Ellipsoid:
    cdef shared_ptr[CEllipsoid] thisptr
    def __cinit__(self, dim=0, construct_new_cpp_object=True):
        if construct_new_cpp_object:
            self.thisptr = shared_ptr[CEllipsoid](new CEllipsoid(dim))
    @staticmethod
    cdef wrap(shared_ptr[CEllipsoid] ptr):
        pyobj = Ellipsoid(construct_new_cpp_object=False)
        pyobj.thisptr = ptr
        return pyobj

    @staticmethod
    def fromNSphere(center, double radius=ELLIPSOID_C_EPSILON):
        cdef np.ndarray[double, ndim=1, mode="c"] d = np.asarray(center, dtype=np.float64)
        cdef VectorXd d_vec = copyToVector(&d[0], d.shape[0])
        return Ellipsoid.wrap(CEllipsoid.fromNSphere(d_vec, radius))

    def getDimension(self):
        return self.thisptr.get().getDimension()
    def setC(self, np.ndarray[double, ndim=2, mode="c"] C not None):
        cdef MatrixXd C_mat = copyToMatrix(&C[0,0], C.shape[0], C.shape[1])
        self.thisptr.get().setC(C_mat)
    def getC(self):
        return eigenMatrixToNumpy(self.thisptr.get().getC())
    def setD(self, np.ndarray[double, ndim=1, mode="c"] d not None):
        cdef VectorXd d_vec = copyToVector(&d[0], d.shape[0])
        self.thisptr.get().setD(d_vec)
    def getD(self):
        return eigenVectorToNumpy(self.thisptr.get().getD())
    def getVolume(self):
        return self.thisptr.get().getVolume()
    def draw2d(self, ax=None, **kwargs):
        if ax is None:
            ax = plt.gca()
        theta = np.linspace(0, 2 * np.pi, 100)
        y = np.vstack((np.sin(theta), np.cos(theta)))
        points = (self.getC().dot(y) + self.getD()[:,np.newaxis]).T
        hull = scipy.spatial.ConvexHull(points)
        kwargs.setdefault("edgecolor", "b")
        kwargs.setdefault("facecolor", "none")
        ax.add_patch(plt.Polygon(xy=points[hull.vertices],**kwargs))
    def draw(self, ax=None, **kwargs):
        if self.getDimension() == 2:
            self.draw2d(ax=ax, **kwargs)
        else:
            raise NotImplementedError("drawing for dimension greater than 2 not implemented yet")

cdef class IRISRegion:
    cdef shared_ptr[CIRISRegion] thisptr
    def __cinit__(self, dim=0, construct_new_cpp_object=True):
        if construct_new_cpp_object:
            self.thisptr = shared_ptr[CIRISRegion](new CIRISRegion(dim))
    @staticmethod
    cdef wrap(shared_ptr[CIRISRegion] ptr):
        pyobj = IRISRegion(dim=ptr.get().polytope.get().getDimension(), construct_new_cpp_object=False)
        pyobj.thisptr = ptr
        return pyobj

    def getPolytope(self):
        return Polytope.wrap(self.thisptr.get().polytope)

    def getEllipsoid(self):
        return Ellipsoid.wrap(self.thisptr.get().ellipsoid)

cdef class IRISDebugData:
    cdef shared_ptr[CIRISDebugData] thisptr
    def __cinit__(self, construct_new_cpp_object=True):
        if construct_new_cpp_object:
            self.thisptr = shared_ptr[CIRISDebugData](new CIRISDebugData());
    @staticmethod
    cdef wrap(shared_ptr[CIRISDebugData] ptr):
        pyobj = IRISDebugData(construct_new_cpp_object=False)
        pyobj.thisptr = ptr
        return pyobj
    def getNumberOfPolytopes(self):
        return self.thisptr.get().polytope_history.size()
    def getNumberOfEllipsoids(self):
        return self.thisptr.get().ellipsoid_history.size()
    def getPolytope(self, index=-1):
        print "getting polytope: ", index
        if index < 0:
            index = self.getNumberOfPolytopes() + index
        if index >= self.getNumberOfPolytopes():
            raise IndexError("polytope index out of bounds")
        poly = Polytope(dim=self.thisptr.get().polytope_history[index].getDimension())
        poly.thisptr.get()[0] = self.thisptr.get().polytope_history[index]
        return poly
    def iterPolytopes(self):
        for i in xrange(self.getNumberOfPolytopes()):
            yield self.getPolytope(i)
    def getEllipsoid(self, index=-1):
        if index < 0:
            index = self.getNumberOfEllipsoids() + index
        if index >= self.getNumberOfEllipsoids():
            raise IndexError("ellipsoid index out of bounds")
        ellipsoid = Ellipsoid(dim=self.thisptr.get().ellipsoid_history[index].getDimension())
        ellipsoid.thisptr.get()[0] = self.thisptr.get().ellipsoid_history[index]
        return ellipsoid
    def iterEllipsoids(self):
        for i in xrange(self.getNumberOfEllipsoids()):
            yield self.getEllipsoid(i)
    def iterRegions(self):
        return itertools.izip(self.iterPolytopes(), self.iterEllipsoids())

def inflate_region(obstacles, start_point_or_ellipsoid, Polytope bounds=None,
                  require_containment=False,
                  error_on_infeasible_start=False,
                  termination_threshold=2e-3,
                  iter_limit = 100,
                  return_debug_data=False):

    cdef Ellipsoid start
    if isinstance(start_point_or_ellipsoid, Ellipsoid):
        start = start_point_or_ellipsoid
    else:
        start = Ellipsoid.fromNSphere(start_point_or_ellipsoid)

    cdef int dim = start.getDimension()
    cdef CIRISProblem *problem = new CIRISProblem(dim)

    if bounds is None:
        bounds = Polytope(dim)
    problem.setBounds(deref(bounds.thisptr))
    problem.setSeedEllipsoid(deref(start.thisptr))

    cdef CIRISOptions options
    options.require_containment = require_containment
    options.error_on_infeasible_start = error_on_infeasible_start
    options.termination_threshold = termination_threshold
    options.iter_limit = iter_limit
    cdef MatrixXd obs_mat
    cdef np.ndarray[double, ndim=2, mode="c"] obs
    try:
        for obs in obstacles:
            assert(obs.shape[0] == dim, "Obstacle points should be size dim x num_points")
            obs_mat = copyToMatrix(&obs[0,0], obs.shape[0], obs.shape[1])
            problem.addObstacle(obs_mat)
        if return_debug_data:
            debug = IRISDebugData()
            region = IRISRegion.wrap(cinflate_region(deref(problem), options, debug.thisptr.get()))
        else:
            region = IRISRegion.wrap(cinflate_region(deref(problem), options))
    except Exception as e:
        print e
    finally:
        del problem
    if return_debug_data:
        return region, debug
    else:
        return region