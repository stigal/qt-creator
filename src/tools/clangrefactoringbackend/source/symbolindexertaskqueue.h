/****************************************************************************
**
** Copyright (C) 2018 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of Qt Creator.
**
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3 as published by the Free Software
** Foundation with exceptions as appearing in the file LICENSE.GPL3-EXCEPT
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-3.0.html.
**
****************************************************************************/

#pragma once

#include <filepathid.h>

#include <utils/smallstringvector.h>

#include <functional>
#include <vector>

namespace ClangBackEnd {

class SymbolsCollectorInterface;
class SymbolStorageInterface;

class SymbolIndexerTask
{
public:
    using Callable = std::function<void(SymbolsCollectorInterface &symbolsCollector,
                                        SymbolStorageInterface &symbolStorage)>;

    SymbolIndexerTask(FilePathId filePathId,
                      std::size_t projectPartId,
                      Callable &&callable)
        : callable(std::move(callable)),
          filePathId(filePathId),
          projectPartId(projectPartId)
    {
    }

    SymbolIndexerTask clone() const
    {
        return *this;
    }

    friend
    bool operator==(const SymbolIndexerTask &first, const SymbolIndexerTask &second)
    {
        return first.filePathId == second.filePathId && first.projectPartId == second.projectPartId;
    }

    friend
    bool operator<(const SymbolIndexerTask &first, const SymbolIndexerTask &second)
    {
        return std::tie(first.filePathId, first.projectPartId)
             < std::tie(second.filePathId, second.projectPartId);
    }

public:
    Callable callable;
    FilePathId filePathId;
    std::size_t projectPartId;
};

class SymbolIndexerTaskQueue
{
public:
    SymbolIndexerTaskQueue();

    void addOrUpdateTasks(std::vector<SymbolIndexerTask> &&tasks)
    /* [[expects: std::is_sorted(tasks)]] */;
    void removeTasks(const Utils::SmallStringVector &projectPartIds)
    /* [[expects: std::is_sorted(projectPartIds)]] */;

    const std::vector<SymbolIndexerTask> &tasks() const;

    std::size_t projectPartNumberId(Utils::SmallStringView projectPartId);
    std::vector<std::size_t> projectPartNumberIds(const Utils::SmallStringVector &projectPartIds)
    /* [[ensures result: std::is_sorted(result)]] */;

private:
    std::vector<Utils::SmallString> m_projectPartIds;
    std::vector<SymbolIndexerTask> m_tasks;
};

} // namespace ClangBackEnd
