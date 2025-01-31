/* ============================================================================
* Copyright (c) 2009-2016 BlueQuartz Software, LLC
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* Redistributions of source code must retain the above copyright notice, this
* list of conditions and the following disclaimer.
*
* Redistributions in binary form must reproduce the above copyright notice, this
* list of conditions and the following disclaimer in the documentation and/or
* other materials provided with the distribution.
*
* Neither the name of BlueQuartz Software, the US Air Force, nor the names of its
* contributors may be used to endorse or promote products derived from this software
* without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
* USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* The code contained herein was partially funded by the followig contracts:
*    United States Air Force Prime Contract FA8650-07-D-5800
*    United States Air Force Prime Contract FA8650-10-D-5210
*    United States Prime Contract Navy N00173-07-C-2068
*
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

#ifndef _emsoftapplication_h_
#define _emsoftapplication_h_

#include <QtCore/QSet>
#include <QtCore/QSharedPointer>

#include <QtWidgets/QApplication>
#include <QtWidgets/QMenuBar>

#include "SIMPLib/Common/SIMPLibSetGetMacros.h"

#define emSoftApp (static_cast<EMsoftApplication*>(qApp))

class EMsoftWorkbench;
class LandingWidget;

class EMsoftApplication : public QApplication
{
  Q_OBJECT

public:
  EMsoftApplication(int& argc, char** argv);
  ~EMsoftApplication();

  SIMPL_INSTANCE_PROPERTY(LandingWidget*, LandingWidget)
  SIMPL_INSTANCE_PROPERTY(QString, OpenDialogLastDirectory)

  bool initialize(int argc, char* argv[]);

  QList<EMsoftWorkbench*> getEMsoftWorkbenchInstances();

  void registerEMsoftWorkbenchWindow(EMsoftWorkbench *window);

  virtual void unregisterEMsoftWorkbenchWindow(EMsoftWorkbench* window);

  EMsoftWorkbench* getNewEMsoftWorkbenchInstance(QString filePath);

  EMsoftWorkbench* getActiveWindow();
  void setActiveWindow(EMsoftWorkbench* instance);

public slots:
  void newInstanceFromFile(const QString& filePath, const bool& setOpenedFilePath, const bool& addToRecentFiles);

protected:
  // This is a set of all SIMPLView instances currently available
  QList<EMsoftWorkbench*> m_EMsoftWorkbenchInstances;

  // The currently active SIMPLView instance
  EMsoftWorkbench* m_ActiveWindow;

protected slots:
  void on_actionOpen_triggered();
  void on_actionSave_triggered();
  void on_actionSaveAs_triggered();

  void on_actionCloseWindow_triggered();
  void on_actionExit_triggered();
  void on_actionAboutEMsoftWorkbench_triggered();

  virtual void emSoftWindowChanged(EMsoftWorkbench* instance);

  virtual void landingWidgetWindowChanged();

  virtual void on_actionClearRecentFiles_triggered();

  void openMasterFile(const QString &path);

private:

  EMsoftApplication(const EMsoftApplication&); // Copy Constructor Not Implemented
  void operator=(const EMsoftApplication&);       // Operator '=' Not Implemented
};

#endif /* _emsoftapplication_h_ */
