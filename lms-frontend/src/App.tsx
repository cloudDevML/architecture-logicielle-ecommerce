import React, {useEffect, lazy, Suspense} from 'react';
import {BrowserRouter as Router, Routes, Route, Navigate, useParams, useLocation} from 'react-router-dom';
import { AuthProvider } from './services/AuthContext';
import { ThemeProvider } from './services/ThemeContext';
import { MeetingProvider } from './context/MeetingContext';
import keycloak from './services/keycloak';
import PrivateRoute from './services/PrivateRoute';
import { ToastContainer } from 'react-toastify';
import { ErrorBoundary } from './components/ui';
import { Loading } from './components/ui';
import 'react-toastify/dist/ReactToastify.css';

// Code splitting - lazy load heavy routes
const AdminLayout = lazy(() => import('./pages/Admin/AdminLayout'));
const LecturerLayout = lazy(() => import('./pages/Lecturer/LecturerLayout'));
const StudentLayout = lazy(() => import('./pages/Student/StudentLayout'));
const MeetingRoom = lazy(() => import('./pages/Meeting/MeetingRoom'));
const Storefront = lazy(() => import('./pages/public/Storefront'));

const LecturerOnboarding = lazy(() => import('./pages/Admin/lecturer/LecturerOnboarding'));
const Announcements = lazy(() => import('./pages/Admin/communication/Announcements'));
const NewAnnounce = lazy(() => import('./pages/Admin/communication/NewAnnounce'));
const Messages = lazy(() => import('./pages/Admin/communication/Messages'));
const Establishment = lazy(() => import('./pages/Admin/university/establishment/Establishment'));
const NewEstablishment = lazy(() => import('./pages/Admin/university/establishment/NewEstablishment'));
const EstablishmentDetails = lazy(() => import('./pages/Admin/university/establishment/EstablishmentDetails'));
const Cycle = lazy(() => import('./pages/Admin/university/cycle/Cycle'));
const NewCycle = lazy(() => import('./pages/Admin/university/cycle/NewCycle'));
const CycleDetails = lazy(() => import('./pages/Admin/university/cycle/CycleDetails'));
const Class = lazy(() => import('./pages/Admin/university/class/Class'));
const NewClass = lazy(() => import('./pages/Admin/university/class/NewClass'));
const ClassDetails = lazy(() => import('./pages/Admin/university/class/ClassDetails'));
const AdminTimetablePage = lazy(() => import('./pages/Admin/university/TimetablePage'));
const Course = lazy(() => import('./pages/Admin/university/course/Course'));
const Department = lazy(() => import('./pages/Admin/university/department/Department'));
const NewDepartment = lazy(() => import('./pages/Admin/university/department/NewDepartment'));
const DepartmentDetails = lazy(() => import('./pages/Admin/university/department/DepartmentDetails'));
const NewCourse = lazy(() => import("./pages/Admin/university/course/NewCourse"));
const CourseDetails = lazy(() => import("./pages/Admin/university/course/CourseDetails"));
const NotFound = lazy(() => import("./pages/public/NotFound"));
const Dashboard = lazy(() => import("./pages/Admin/dashboard/Dashboard"));
const Module = lazy(() => import("./pages/Admin/university/modules/Module"));
const NewModule = lazy(() => import("./pages/Admin/university/modules/NewModule"));
const ModuleDetails = lazy(() => import("./pages/Admin/university/modules/ModuleDetails"));
const Unauthorized = lazy(() => import("./pages/public/Unauthorized"));
const Home = lazy(() => import("./pages/Student/Home/Home"));
const Materials = lazy(() => import("./pages/Student/Materials/materials"));
const StudentQuiz = lazy(() => import("./pages/Student/Quiz/Quiz"));
const AdaptiveQuiz = lazy(() => import("./pages/Student/Quiz/AdaptiveQuiz"));
const ThreadDetails = lazy(() => import("./pages/Student/Forum/ThreadDetails"));
const StudentModuleDetail = lazy(() => import("./pages/Student/ModuleDetail/ModuleDetail"));
const EnrolledStudent = lazy(() => import("./pages/Admin/student/EnrolledStudent"));
const StudentDetails = lazy(() => import("./pages/Admin/student/StudentDetails"));
const LecturerDetails = lazy(() => import("./pages/Admin/lecturer/LecturerDetails"));
const NewStudent = lazy(() => import("./pages/Admin/student/NewStudent"));
const NewLecturer = lazy(() => import("./pages/Admin/lecturer/NewLecturer"));
const Profile = lazy(() => import("./pages/Student/Profile/Profile"));
const Grades = lazy(() => import("./pages/Student/Grades/Grades"));
const Leaderboard = lazy(() => import("./pages/Student/Leaderboard/Leaderboard"));
const Mentorship = lazy(() => import("./pages/Student/Mentorship/Mentorship"));
const LecturerHome = lazy(() => import("./pages/Lecturer/Home/Home"));
const LecturerAnnouncements = lazy(() => import("./pages/Lecturer/Announcements/Announcements"));
const LecturerMaterials = lazy(() => import("./pages/Lecturer/Materials/materials"));
const LecturerQuiz = lazy(() => import("./pages/Lecturer/Quiz/Quiz"));
const LecturerModuleDetail = lazy(() => import("./pages/Lecturer/ModuleDetail/ModuleDetail"));
const LecturerProfile = lazy(() => import("./pages/Lecturer/Profile/Profile"));
const LecturerMentorship = lazy(() => import("./pages/Lecturer/Mentorship/Mentorship"));
const AtRiskStudents = lazy(() => import('./pages/Lecturer/AtRiskStudents/AtRiskStudents'));
const AllLecturers = lazy(() => import("./pages/Admin/lecturer/AllLecturers"));
const Settings = lazy(() => import("./pages/Admin/others/Settings"));
const Support = lazy(() => import("./pages/Admin/others/Support"));
const AdminAttendanceList = lazy(() => import("./pages/Admin/Attendance/AttendanceList"));
const PedagogicalDashboard = lazy(() => import("./pages/Admin/Analytics/PedagogicalDashboard"));
const Certificates = lazy(() => import("./pages/Student/Certificates/Certificates"));
const Analytics = lazy(() => import("./pages/Student/Analytics/Analytics"));
const StudentAnnouncements = lazy(() => import("./pages/Student/Announcements/Announcements"));
const StudentTimetablePage = lazy(() => import("./pages/Student/Timetable/TimetablePage"));
const PracticeCatalog = lazy(() => import("./pages/Practice/PracticeCatalog"));
const PracticePage = lazy(() => import("./pages/Practice/PracticePage"));
const PracticeSolve = lazy(() => import("./pages/Practice/PracticeSolve"));
const PracticePlayground = lazy(() => import("./pages/Practice/PracticePlayground"));
const PracticeBuilder = lazy(() => import("./pages/Practice/PracticeBuilder"));
const CourseDetail = lazy(() => import("./pages/Practice/CourseDetail"));
const ResponsivePracticeGuard = lazy(() => import("./components/Practice/ResponsivePracticeGuard"));

// Focus Layouts for full-screen immersive modes
const FocusLayout = lazy(() => import('./layouts/FocusLayout'));
const AssignmentTakePage = lazy(() => import('./pages/Student/ModuleDetail/AssignmentTakePage'));
const AssignmentBuilderPage = lazy(() => import('./pages/Lecturer/ModuleDetail/AssignmentBuilderPage'));

const ForumRedirect = ({ role }: { role: 'student' | 'lecturer' }) => {
    const { id } = useParams();
    return <Navigate to={`/${role}/${id}`} state={{ activeTab: 'forum' }} replace />;
};

const GlobalFooter = () => {
    const location = useLocation();
    if (location.pathname.includes('/take') || location.pathname.includes('/edit') || location.pathname.includes('/quiz')) return null;
    return (
        <footer style={{
            textAlign: 'center', padding: '1.5rem', background: 'var(--bg-base)', borderTop: '1px solid var(--border)',
            color: 'var(--text-secondary)', fontSize: '0.85rem', marginTop: 'auto', width: '100%', zIndex: 100
        }}>
            <div className="container">
                <strong>Copyright &copy; {new Date().getFullYear()} <span style={{ color: 'var(--accent)', fontWeight: 700 }}>EPT LMS</span>.</strong> Tous droits réservés.
            </div>
        </footer>
    );
};

const LogoutRedirect: React.FC = () => {
    useEffect(() => {
        localStorage.clear();
        keycloak.logout({ redirectUri: window.location.origin });
    }, []);

    return (
        <div style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            height: '100vh',
            background: 'var(--bg-main)',
            color: 'var(--text-main)',
            fontFamily: 'sans-serif'
        }}>
            <div style={{
                border: '4px solid rgba(0,0,0,0.1)',
                width: '36px',
                height: '36px',
                borderRadius: '50%',
                borderLeftColor: '#007bff',
                animation: 'spin 1s linear infinite',
                marginBottom: '15px'
            }}></div>
            <style>{`
                @keyframes spin {
                    0% { transform: rotate(0deg); }
                    100% { transform: rotate(360deg); }
                }
            `}</style>
            <h4 style={{ fontWeight: 600, margin: '0 0 5px 0' }}>Déconnexion sécurisée...</h4>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', margin: 0 }}>Veuillez patienter pendant que nous libérons votre session SSO.</p>
        </div>
    );
};

const App: React.FC = () => {


    useEffect(() => {
        const path = window.location.pathname;
        if (path.startsWith('/student') || path.startsWith('/lecturer')) {
            document.body.className = 'hold-transition layout-top-nav';
        } else {
            document.body.className = 'hold-transition sidebar-mini layout-fixed layout-navbar-fixed';
        }
    }, [window.location.pathname]);

    return (
        <ThemeProvider>
        <Router>
            <ToastContainer
                position="top-right"
                autoClose={5000}
                hideProgressBar={false}
                newestOnTop
                closeOnClick
                rtl={false}
                pauseOnFocusLoss
                draggable
                pauseOnHover
                theme="colored"
            />
            <AuthProvider>
              <MeetingProvider>
                <ErrorBoundary>
                  <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
                  <Suspense fallback={<Loading text="Chargement..." overlay />}>
                  <Routes>
                      <Route path="/store" element={<Storefront />} />
                      <Route path="/catalogue" element={<Storefront />} />
                      <Route path="/shop" element={<Storefront />} />
                      <Route path="/login" element={<LogoutRedirect />} />
                      <Route path="/unauthorized" element={<Unauthorized />} />
                      <Route path="/meeting" element={
                          <PrivateRoute element={<MeetingRoom />} allowedGroups={['STUDENT', 'LECTURER', 'CHEF_DEPT', 'RESP_PEDAGO', 'ADMIN']} />
                      } />
                      <Route path="/student/:moduleId/assignment/:assignmentId/take" element={
                          <PrivateRoute element={<FocusLayout><AssignmentTakePage /></FocusLayout>} allowedGroups={['STUDENT']} />
                      } />
                      <Route path="/lecturer/:moduleId/assignment/:assignmentId/edit" element={
                          <PrivateRoute element={<FocusLayout><AssignmentBuilderPage /></FocusLayout>} allowedGroups={['LECTURER', 'CHEF_DEPT', 'RESP_PEDAGO']} />
                      } />
                      <Route path="/student/:moduleId/quiz/:quizId" element={
                          <PrivateRoute element={<FocusLayout><StudentQuiz /></FocusLayout>} allowedGroups={['STUDENT']} />
                      } />
                      <Route path="/lecturer/:moduleId/quiz/:quizId" element={
                          <PrivateRoute element={<FocusLayout><LecturerQuiz /></FocusLayout>} allowedGroups={['LECTURER', 'CHEF_DEPT', 'RESP_PEDAGO']} />
                      } />
                      <Route
                          path="/"
                          element={
                              <PrivateRoute element={<div />} allowedGroups={['ADMIN', 'SCOLARITE', 'STUDENT', 'LECTURER', 'CHEF_DEPT', 'RESP_PEDAGO']} />
                          }
                      />
                      <Route
                          path="/admin/*"
                          element={
                              <PrivateRoute element={
                                  <AdminLayout>
                                      <Routes>
                                          <Route path="index" element={<Dashboard />} />
                                          <Route path="university/establishment" element={<Establishment />} />
                                          <Route path="university/establishment/new" element={<NewEstablishment />} />
                                          <Route path="university/establishment/:id/details" element={<EstablishmentDetails />} />
                                          <Route path="university/cycle" element={<Cycle />} />
                                          <Route path="university/cycle/new" element={<NewCycle />} />
                                          <Route path="university/cycle/:id/details" element={<CycleDetails />} />
                                          <Route path="university/class" element={<Class />} />
                                          <Route path="university/class/new" element={<NewClass />} />
                                          <Route path="university/class/:id/details" element={<ClassDetails />} />

                                          <Route path="university/department" element={<Department />} />
                                          <Route path="university/department/new" element={<NewDepartment />} />
                                          <Route path="university/department/:id/details" element={<DepartmentDetails />} />
                                          <Route path="university/timetable" element={<AdminTimetablePage />} />
                                          <Route path="university/course" element={<Course />} />
                                          <Route path="university/course/new" element={<NewCourse />} />
                                          <Route path="university/course/:id/details" element={<CourseDetails />} />
                                          <Route path="university/module" element={<Module />} />
                                          <Route path="university/module/new" element={<NewModule />} />
                                          <Route path="university/module/:id/details" element={<ModuleDetails />} />
                                          <Route path="student/enrolled" element={<EnrolledStudent />} />
                                          <Route path="student/:id/details" element={<StudentDetails />} />
                                          <Route path="student/new" element={<NewStudent />} />
                                          <Route path="lecturer/onboarding" element={<LecturerOnboarding />} />
                                          <Route path="lecturer/new" element={<NewLecturer />} />
                                          <Route path="lecturer/all" element={<AllLecturers />} />
                                          <Route path="lecturer/:id/details" element={<LecturerDetails />} />
                                          <Route path="announcements" element={<Announcements />} />
                                          <Route path="announcements/new" element={<NewAnnounce />} />
                                          <Route path="messages" element={<Messages />} />
                                          <Route path="settings" element={<Settings />} />
                                          <Route path="support" element={<Support />} />
                                          <Route path="analytics" element={<PedagogicalDashboard />} />
                                          <Route path="attendance" element={<AdminAttendanceList />} />
                                      </Routes>
                                  </AdminLayout>
                              } allowedGroups={['ADMIN', 'SCOLARITE', 'CHEF_DEPT', 'RESP_PEDAGO']} />
                          }
                      />
                      <Route
                          path="/student/*"
                          element={
                              <PrivateRoute element={
                                  <StudentLayout>
                                      <Routes>
                                          <Route path="" element={<Home />} />
                                          <Route path="announcements" element={<StudentAnnouncements />} />
                                          <Route path="grades" element={<Grades />} />
                                          <Route path="profile" element={<Profile />} />
                                          <Route path="leaderboard" element={<Leaderboard />} />
                                          <Route path="mentorship" element={<Mentorship />} />
                                          <Route path="certificates" element={<Certificates />} />
                                          <Route path="analytics" element={<Analytics />} />
                                          <Route path="timetable" element={<StudentTimetablePage />} />
                                          <Route path="practice" element={<ResponsivePracticeGuard><PracticePage /></ResponsivePracticeGuard>} />
                                          <Route path="practice/playground" element={<ResponsivePracticeGuard><PracticePlayground /></ResponsivePracticeGuard>} />
                                          <Route path="practice/explore/:courseId" element={<ResponsivePracticeGuard><CourseDetail /></ResponsivePracticeGuard>} />
                                          <Route path="practice/explore/:courseId/:lessonId" element={<ResponsivePracticeGuard><CourseDetail /></ResponsivePracticeGuard>} />
                                          <Route path="practice/:exerciseId" element={<ResponsivePracticeGuard><PracticeSolve /></ResponsivePracticeGuard>} />
                                          <Route path=":id" element={<StudentModuleDetail />} />
                                          <Route path=":id/materials" element={<Materials />} />
                                          <Route path=":id/adaptive-quiz" element={<AdaptiveQuiz />} />
                                          <Route path=":id/forum" element={<ForumRedirect role="student" />} />
                                          <Route path=":id/forum/thread/:threadId" element={<ThreadDetails />} />
                                          <Route path="messages" element={<Messages />} />
                                      </Routes>
                                  </StudentLayout>
                              } allowedGroups={['STUDENT']} />
                          }
                      />
                      <Route
                          path="/lecturer/*"
                          element={
                              <PrivateRoute element={
                                  <LecturerLayout>
                                      <Routes>
                                          <Route path="" element={<LecturerHome />} />
                                          <Route path="announcements" element={<LecturerAnnouncements />} />
                                          <Route path="mentorship" element={<LecturerMentorship />} />
                                          <Route path=":id" element={<LecturerModuleDetail />} />
                                          <Route path=":id/materials" element={<LecturerMaterials />} />
                                          <Route path=":id/forum" element={<ForumRedirect role="lecturer" />} />
                                          <Route path=":id/forum/thread/:threadId" element={<ThreadDetails />} />
                                          <Route path="profile" element={<LecturerProfile />} />
                                          <Route path="at-risk" element={<AtRiskStudents />} />
                                        <Route path="practice" element={<PracticeBuilder />} />
                                          <Route path="messages" element={<Messages />} />
                                      </Routes>
                                  </LecturerLayout>
                              } allowedGroups={['LECTURER', 'CHEF_DEPT', 'RESP_PEDAGO']} />
                          }
                      />
                      <Route path="*" element={<NotFound />} />
                  </Routes>
                  </Suspense>
                  <GlobalFooter />
                  </div>
                </ErrorBoundary>
              </MeetingProvider>
            </AuthProvider>
        </Router>
        </ThemeProvider>
    )
}

export default App;
