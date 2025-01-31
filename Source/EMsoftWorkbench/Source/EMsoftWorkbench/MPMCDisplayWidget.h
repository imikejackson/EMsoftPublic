/* ============================================================================
* Copyright (c) 2009-2017 BlueQuartz Software, LLC
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

#ifndef _mpmcdisplaywidget_h_
#define _mpmcdisplaywidget_h_

#include <QtCore/QObject>

#include "SIMPLib/Common/SIMPLibSetGetMacros.h"

#include "EMsoftWorkbench/GLImageDisplayWidget.h"

#include "ui_MPMCDisplayWidget.h"

class MPMCDisplayWidget : public GLImageDisplayWidget, public Ui::MPMCDisplayWidget
{
    Q_OBJECT

  public:
    MPMCDisplayWidget(QWidget* parent = 0, Qt::WindowFlags windowFlags = Qt::WindowFlags());
    ~MPMCDisplayWidget();

    SIMPL_INSTANCE_PROPERTY(std::vector<QImage>, ImageVector)

    using EnumType = unsigned int;

    enum class ProjectionMode : EnumType
    {
      Lambert_Square,
      Lambert_Circle,
      Stereographic
    };

    void setProjectionMode(MPMCDisplayWidget::ProjectionMode mode);

  public slots:
    /**
     * @brief loadImage
     * @param image
     */
    void loadImage(GLImageDisplayWidget::GLImageData data);

    /**
     * @brief setKeV
     * @param keV
     */
    void setKeV(float keV);

  protected:
    void setupGui();

  protected slots:
    /**
     * @brief on_energyBinSpinBox_valueChanged
     * @param value
     */
    void on_energyBinSpinBox_valueChanged(int value);

    /**
     * @brief setEnergyBinSpinBoxRange
     * @param min
     * @param max
     */
    void setEnergyBinSpinBoxRange(int min, int max);

    /**
     * @brief on_saveBtn_pressed
     */
    void on_saveBtn_pressed();

    /**
     * @brief projModeChanged
     */
    void projModeChanged(int mode);

  signals:
    void controlsChanged(int sliderValue, MPMCDisplayWidget::ProjectionMode projMode);
    void statusMsgGenerated(QString msg);

  private slots:
    void updateSliderRange(int, int);

  private:
    QActionGroup*       m_ProjModeMenuActionGroup = nullptr;
    QAction*            m_LambertSquareAction = nullptr;
    QAction*            m_LambertCircleAction = nullptr;
    QAction*            m_StereographicAction = nullptr;
    ProjectionMode      m_ProjectionMode = ProjectionMode::Lambert_Square;

    MPMCDisplayWidget(const MPMCDisplayWidget&);    // Copy Constructor Not Implemented
    void operator=(const MPMCDisplayWidget&);  // Operator '=' Not Implemented
};

#endif /* _mpmcdisplaywidget_h_ */
