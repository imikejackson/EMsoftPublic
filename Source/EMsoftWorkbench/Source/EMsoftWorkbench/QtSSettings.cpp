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

#include "QtSSettings.h"

#include <iostream>

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QJsonDocument>
#include <QtCore/QSettings>
#include <QtCore/QTextCodec>

#include <QtWidgets/QTreeWidgetItemIterator>

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QtSSettings::QtSSettings(QObject* parent)
{
  setParent(parent);

#if defined(Q_OS_MAC)
  QSettings::Format format = QSettings::NativeFormat;
#else
  QSettings::Format format = QSettings::IniFormat;
#endif

  QSettings prefs(format, QSettings::UserScope, QCoreApplication::organizationDomain(), QCoreApplication::applicationName());
  QString oldFilePath = prefs.fileName();

  QFileInfo fi(oldFilePath);

  QString appName = QCoreApplication::applicationName();
  if(appName.isEmpty())
  {
    appName = QString("Application");
  }

#if defined(Q_OS_MAC)

  QString domain = QCoreApplication::organizationDomain();
  if(domain.isEmpty())
  {
    domain = QString("Domain");
  }
  QStringList tokens = domain.split(".");
  QStringListIterator iter(tokens);
  iter.toBack();
  domain = QString("");
  while(iter.hasPrevious())
  {
    domain = domain + iter.previous() + QString(".");
  }

  QString newFilePath = fi.path() + "/" + domain + appName + ".json";
#else
  QString newFilePath = fi.path() + "/" + appName + ".json";
#endif

  m_FilePath = QDir::toNativeSeparators(newFilePath);

  // Open the file and read the contents, if it exists
  openFile();
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QtSSettings::QtSSettings(const QString& filePath, QObject* parent)
{
  setParent(parent);

  m_FilePath = filePath;

  // Open the file and read the contents, if it exists
  openFile();
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QtSSettings::~QtSSettings()
{
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QString QtSSettings::fileName()
{
  return m_FilePath;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
bool QtSSettings::contains(const QString& key)
{
  return m_Stack.top()->group.contains(key);
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
bool QtSSettings::beginGroup(const QString& prefix)
{
  if(prefix.isEmpty())
  {
    return false;
  }
  else if(m_Stack.isEmpty() == false && m_Stack.top()->group.contains(prefix) == true && m_Stack.top()->group[prefix].isObject() == true)
  {
    SIMPLViewSettingsGroup::Pointer newGroup = SIMPLViewSettingsGroup::Pointer(new SIMPLViewSettingsGroup(prefix, m_Stack.top()->group[prefix].toObject()));
    m_Stack.push(newGroup);
  }
  else
  {
    SIMPLViewSettingsGroup::Pointer newGroup = SIMPLViewSettingsGroup::Pointer(new SIMPLViewSettingsGroup(prefix, QJsonObject()));
    m_Stack.push(newGroup);
  }

  return true;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::endGroup()
{
  writeToFile();

  if(m_Stack.size() > 1)
  {
    SIMPLViewSettingsGroup::Pointer group = m_Stack.pop();
  }
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QStringList QtSSettings::childGroups()
{
  QStringList list;
  QJsonObject obj = m_Stack.top()->group;

  QStringList keyList = obj.keys();

  for(int i = 0; i < keyList.size(); i++)
  {
    if(obj.value(keyList[i]).isObject())
    {
      list.append(keyList[i]);
    }
  }

  return list;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::remove(const QString& key)
{
  QJsonObject obj = m_Stack.top()->group;

  obj.remove(key);
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::clear()
{
  m_Stack.first()->group = QJsonObject();
  writeToFile();
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QVariant QtSSettings::value(const QString& key, const QVariant& defaultValue)
{
  if(m_Stack.top()->group.contains(key) == false)
  {
    return defaultValue;
  }

  return m_Stack.top()->group.value(key).toVariant();
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QJsonObject QtSSettings::value(const QString& key, const QJsonObject& defaultObject)
{
  if(m_Stack.top()->group.contains(key) == false)
  {
    return defaultObject;
  }

  if(m_Stack.top()->group[key].isObject())
  {
    return m_Stack.top()->group[key].toObject();
  }
  return defaultObject;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QStringList QtSSettings::value(const QString& key, const QStringList& defaultList)
{
  if(m_Stack.top()->group[key].isArray() == false)
  {
    return defaultList;
  }

  QJsonArray jsonArray = m_Stack.top()->group[key].toArray();
  QStringList list;

  for(int i = 0; i < jsonArray.size(); i++)
  {
    QString str = jsonArray[i].toString();
    list.push_back(str);
  }

  return list;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
QByteArray QtSSettings::value(const QString& key, const QByteArray& defaultValue)
{
  Q_UNUSED(defaultValue);
  QString value = m_Stack.top()->group[key].toString();
  QByteArray byteArray8Bit = value.toLocal8Bit();
  QByteArray byteArray = QByteArray::fromBase64(byteArray8Bit);
  return byteArray;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::setValue(const QString& key, const QByteArray& value)
{
  QString str = QString::fromLocal8Bit(value.toBase64());
  m_Stack.top()->group.insert(key, str);
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::setValue(const QString& key, const QVariant& value)
{

  QJsonValue val = QJsonValue::fromVariant(value);

  if(QString::fromStdString(std::string(value.typeName())) == "QString")
  {
    QJsonArray jsonArray;
    jsonArray.insert(Value, val);
    m_Stack.top()->group.insert(key, val);
  }
  else
  {
    m_Stack.top()->group.insert(key, val);
  }

  // If this is the root, write to the file
  if(m_Stack.top()->groupName.isEmpty())
  {
    writeToFile();
  }
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::setValue(const QString& key, const QJsonObject& object)
{
  m_Stack.top()->group.insert(key, object);

  // If this is the root, write to the file
  if(m_Stack.top()->groupName.isEmpty())
  {
    writeToFile();
  }
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::setValue(const QString& key, const QStringList& list)
{
  QJsonArray jsonArray;

  for(int i = 0; i < list.size(); i++)
  {
    jsonArray.push_back(list[i]);
  }

  m_Stack.top()->group.insert(key, jsonArray);

  // If this is the root, write to the file
  if(m_Stack.top()->groupName.isEmpty())
  {
    writeToFile();
  }
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::openFile()
{
  if(m_Stack.size() > 0)
  {
    closeFile();
  }

  QFile inputFile(m_FilePath);
  if(inputFile.open(QIODevice::ReadOnly))
  {
    QByteArray byteArray = inputFile.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(byteArray);
    SIMPLViewSettingsGroup::Pointer root = SIMPLViewSettingsGroup::Pointer(new SIMPLViewSettingsGroup("", doc.object()));
    m_Stack.push(root);
  }
  else
  {
    SIMPLViewSettingsGroup::Pointer root = SIMPLViewSettingsGroup::Pointer(new SIMPLViewSettingsGroup("", QJsonObject()));
    m_Stack.push(root);
  }
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::closeFile()
{
  m_Stack.clear();
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void QtSSettings::writeToFile()
{
  /* Percolate the information that has changed all the way to the root group
     (The root group is what will ultimately be written to the file) */
  for(int i = m_Stack.size() - 2; i >= 0; i--)
  {
    m_Stack[i]->group[m_Stack[i + 1]->groupName] = m_Stack[i + 1]->group;
  }

  // Write the root to the file
  QFile outputFile(m_FilePath);
  QFileInfo info(outputFile);
  QString parentPath = info.absolutePath();
  QDir parentDir(parentPath);

  if(parentDir.exists() == false)
  {
    parentDir.mkpath(parentPath);
  }

  QJsonDocument doc(m_Stack.front()->group);

  if(outputFile.exists() == true)
  {
    outputFile.remove();
  }
  if(outputFile.open(QIODevice::WriteOnly))
  {
    outputFile.write(doc.toJson());
    outputFile.close();
  }
}
